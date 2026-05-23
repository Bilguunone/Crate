#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_BINARY="$ROOT_DIR/.build/debug/Crate"

if [[ ! -x "$APP_BINARY" ]]; then
  swift build
fi

exec "$APP_BINARY" cratectl "$@"
