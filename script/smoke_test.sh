#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SAMPLE_DIR="$ROOT_DIR/Samples/Crate Sample Paper Textures"

if [[ ! -d "$SAMPLE_DIR" ]]; then
  echo "sample pack missing: $SAMPLE_DIR" >&2
  echo "run: swift script/generate_sample_pack.swift" >&2
  exit 2
fi

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/crate-smoke.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

LIBRARY="$WORK_DIR/DesignAssets"
CRATECTL="$ROOT_DIR/script/cratectl.sh"

"$CRATECTL" --library "$LIBRARY" analyze-folder "$SAMPLE_DIR" --json >/dev/null
"$CRATECTL" --library "$LIBRARY" import-folder "$SAMPLE_DIR" --source "Crate Sample" >/dev/null
"$CRATECTL" --library "$LIBRARY" status | grep -q "assets: 3"
"$CRATECTL" --library "$LIBRARY" search paper --limit 2 | grep -q "paper"
"$CRATECTL" --library "$LIBRARY" cart clear >/dev/null
"$CRATECTL" --library "$LIBRARY" cart add-search paper --limit 2 >/dev/null
"$CRATECTL" --library "$LIBRARY" cart list | grep -q "paper"
"$CRATECTL" --library "$LIBRARY" collection create "Smoke Picks" --from-cart >/dev/null

EXPORT_FOLDER="$("$CRATECTL" --library "$LIBRARY" cart export-folder)"
EXPORT_ZIP="$("$CRATECTL" --library "$LIBRARY" cart export-zip)"

test -d "$EXPORT_FOLDER"
test -f "$EXPORT_ZIP"
"$CRATECTL" --library "$LIBRARY" library validate | grep -q "missing_variant_files: 0"

echo "Crate smoke test passed."
