#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 4 ]]; then
  echo "usage: $0 <root-dir> <app-contents-dir> <info-plist> <minimum-system-version>" >&2
  exit 2
fi

ROOT_DIR="$1"
APP_CONTENTS="$2"
INFO_PLIST="$3"
MIN_SYSTEM_VERSION="$4"

APP_ICON_NAME="${CRATE_APP_ICON_NAME:-Crate}"
ACCENT_COLOR_NAME="${CRATE_ACCENT_COLOR_NAME:-AccentColor}"
ICON_SOURCE="$ROOT_DIR/Resources/$APP_ICON_NAME.icon"
ASSET_CATALOG="$ROOT_DIR/Resources/Crate.xcassets"
APP_RESOURCES="$APP_CONTENTS/Resources"

INPUTS=()
HAS_ICON=0
HAS_ASSET_CATALOG=0

if [[ -d "$ICON_SOURCE" ]]; then
  INPUTS+=("$ICON_SOURCE")
  HAS_ICON=1
else
  echo "warning: app icon source not found: $ICON_SOURCE" >&2
fi

if [[ -d "$ASSET_CATALOG" ]]; then
  INPUTS+=("$ASSET_CATALOG")
  HAS_ASSET_CATALOG=1
fi

if [[ "${#INPUTS[@]}" -eq 0 ]]; then
  echo "warning: no app icon or asset catalog resources found" >&2
  exit 0
fi

if ! xcrun --find actool >/dev/null 2>&1; then
  echo "warning: actool was not found; skipping app icon compilation" >&2
  exit 0
fi

mkdir -p "$APP_RESOURCES"

PARTIAL_INFO="$(mktemp "${TMPDIR:-/tmp}/crate-icon-partial.XXXXXX")"
ACTOOL_OUTPUT="$(mktemp "${TMPDIR:-/tmp}/crate-actool-output.XXXXXX")"
trap 'rm -f "$PARTIAL_INFO" "$ACTOOL_OUTPUT"' EXIT

ACTOOL_ARGS=(
  --compile "$APP_RESOURCES" \
  --platform macosx \
  --minimum-deployment-target "$MIN_SYSTEM_VERSION" \
  --target-device mac \
  --output-partial-info-plist "$PARTIAL_INFO" \
  --standalone-icon-behavior all
)

if [[ "$HAS_ICON" -eq 1 ]]; then
  ACTOOL_ARGS+=(--app-icon "$APP_ICON_NAME")
fi

if [[ "$HAS_ASSET_CATALOG" -eq 1 ]]; then
  ACTOOL_ARGS+=(--accent-color "$ACCENT_COLOR_NAME")
fi

if ! xcrun actool "${ACTOOL_ARGS[@]}" "${INPUTS[@]}" >"$ACTOOL_OUTPUT" 2>&1; then
  cat "$ACTOOL_OUTPUT" >&2
  exit 1
fi

if [[ -s "$PARTIAL_INFO" ]]; then
  /usr/libexec/PlistBuddy -c "Merge $PARTIAL_INFO" "$INFO_PLIST"
fi

if [[ ! -f "$APP_RESOURCES/Assets.car" ]]; then
  echo "error: actool did not produce Assets.car for $ICON_SOURCE" >&2
  exit 1
fi
