# Importing Assets

Crate imports image folders into a managed library. It copies files into `10_Library/packs`, writes SQLite metadata, generates thumbnails, and writes a human-readable manifest.

Source folders are not mutated.

## Supported Files

- PNG
- JPG
- JPEG

Hidden files and non-image files are ignored.

## Recommended Pack Shape

Simple packs work best:

```text
My Paper Pack/
  001.png
  002.png
  003.png
```

Variant pairs are grouped by matching basename:

```text
My Overlay Pack/
  fold-01.png
  fold-01.jpg
  fold-02.png
  fold-02.jpg
```

Crate treats the PNG as transparent and JPG as flat when both exist in the same group.

## Analyze Before Import

```bash
./script/cratectl.sh analyze-folder "/path/to/Asset Pack"
./script/cratectl.sh analyze-folder "/path/to/Asset Pack" --json
```

The analyzer reports:

- proposed pack name
- inferred kind/material/subtype
- image count
- ignored file count
- variant groups
- duplicate basename warnings
- sample normalized names

## Import With Hints

```bash
./script/cratectl.sh import-folder "/path/to/Asset Pack" \
  --kind overlay \
  --material plastic \
  --subtype plastic-wrap \
  --display-name "Plastic Wrap Overlays" \
  --source "Example Vendor"
```

Use stable `--pack-id` and `--short-code` values when you want reproducible filenames across machines.

## Public Repo Rule

Do not commit imported assets, thumbnails, SQLite databases, exports, or third-party asset packs. The repo includes a tiny generated sample pack only for testing Crate itself.
