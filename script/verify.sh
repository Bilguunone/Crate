#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

RUN_PACKAGE=0

for arg in "$@"; do
  case "$arg" in
    --package)
      RUN_PACKAGE=1
      ;;
    --help|-h)
      cat <<USAGE
usage: $0 [--package]

Runs public-clone verification without requiring a Crate asset library.
  --package  also build and sign a local release app bundle
USAGE
      exit 0
      ;;
    *)
      echo "unknown option: $arg" >&2
      exit 2
      ;;
  esac
done

swift build
swift test
./script/cratectl.sh help >/dev/null
./script/smoke_test.sh

if [[ "$RUN_PACKAGE" -eq 1 ]]; then
  ./script/package_app.sh >/dev/null
fi

echo "Crate verification passed."
