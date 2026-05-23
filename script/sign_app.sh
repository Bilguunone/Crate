#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 1 ]]; then
  echo "usage: $0 <app-bundle>" >&2
  exit 2
fi

APP_BUNDLE="$1"
IDENTITY="${CRATE_CODESIGN_IDENTITY:-}"

if [[ -z "$IDENTITY" ]]; then
  IDENTITY="$(security find-identity -p codesigning -v 2>/dev/null | awk -F '"' '/Apple Development/ { print $2; exit }')"
fi

if [[ -n "$IDENTITY" ]]; then
  if /usr/bin/codesign --force --sign "$IDENTITY" --timestamp=none "$APP_BUNDLE" >/dev/null 2>&1; then
    /usr/bin/codesign --verify --deep --strict "$APP_BUNDLE"
    exit 0
  fi

  echo "warning: failed to sign with '$IDENTITY'; falling back to ad-hoc signing" >&2
fi

/usr/bin/codesign --force --sign - --timestamp=none "$APP_BUNDLE" >/dev/null
/usr/bin/codesign --verify --deep --strict "$APP_BUNDLE"
