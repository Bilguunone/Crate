#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Crate"
BUNDLE_ID="${CRATE_BUNDLE_ID:-com.crateapp.crate}"
MIN_SYSTEM_VERSION="${CRATE_MIN_SYSTEM_VERSION:-14.0}"
VERSION="${CRATE_VERSION:-0.1.0}"
BUILD_NUMBER="${CRATE_BUILD:-$(date +%Y%m%d%H%M)}"

INSTALL=0
VERIFY=0

for arg in "$@"; do
  case "$arg" in
    --install)
      INSTALL=1
      ;;
    --verify)
      VERIFY=1
      ;;
    --help|-h)
      cat <<USAGE
usage: $0 [--install] [--verify]

Builds a release Crate.app in ./release, signs it locally, and creates a zip.
  --install  copy Crate.app to /Applications
  --verify   launch the packaged app and verify the process starts
USAGE
      exit 0
      ;;
    *)
      echo "unknown option: $arg" >&2
      exit 2
      ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/release"
APP_BUNDLE="$RELEASE_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_RESOURCES="$APP_CONTENTS/Resources"
ZIP_PATH="$RELEASE_DIR/$APP_NAME-$VERSION-$BUILD_NUMBER.zip"
STAGE_APP_ICON="$ROOT_DIR/script/stage_app_icon.sh"
SIGN_APP="$ROOT_DIR/script/sign_app.sh"

cd "$ROOT_DIR"

swift build -c release
BUILD_BINARY="$(swift build -c release --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

"$STAGE_APP_ICON" "$ROOT_DIR" "$APP_CONTENTS" "$INFO_PLIST" "$MIN_SYSTEM_VERSION"
if [[ -d "$ROOT_DIR/Resources/Pixelmator" ]]; then
  mkdir -p "$APP_RESOURCES"
  rm -rf "$APP_RESOURCES/Pixelmator"
  cp -R "$ROOT_DIR/Resources/Pixelmator" "$APP_RESOURCES/Pixelmator"
  find "$APP_RESOURCES/Pixelmator" -type f -name "pxdctl-*" -exec chmod +x {} \;
fi
/usr/bin/plutil -lint "$INFO_PLIST" >/dev/null
"$SIGN_APP" "$APP_BUNDLE" >/dev/null

rm -f "$ZIP_PATH"
(
  cd "$RELEASE_DIR"
  /usr/bin/ditto -c -k --keepParent --norsrc --noextattr --noqtn "$APP_NAME.app" "$ZIP_PATH"
)

if [[ "$INSTALL" -eq 1 ]]; then
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  rm -rf "/Applications/$APP_NAME.app"
  cp -R "$APP_BUNDLE" "/Applications/$APP_NAME.app"
  /usr/bin/codesign --verify --deep --strict "/Applications/$APP_NAME.app"
fi

if [[ "$VERIFY" -eq 1 ]]; then
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  if [[ "$INSTALL" -eq 1 ]]; then
    /usr/bin/open -n "/Applications/$APP_NAME.app"
  else
    /usr/bin/open -n "$APP_BUNDLE"
  fi
  sleep 1
  pgrep -x "$APP_NAME" >/dev/null
fi

echo "app: $APP_BUNDLE"
echo "zip: $ZIP_PATH"
if [[ "$INSTALL" -eq 1 ]]; then
  echo "installed: /Applications/$APP_NAME.app"
fi
