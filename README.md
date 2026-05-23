# Crate

Crate is a native macOS asset browser for managed design libraries. It imports image packs, normalizes filenames, generates thumbnails, tags assets, lets you browse/filter/search visually, and gives you a shared cart that can be exported from the app, CLI, or MCP wrapper.

It is built with SwiftPM, SwiftUI, SQLite, and local files. No cloud account, no asset subscription wrapper, no fake productivity cult.

## Status

Crate is early but usable. The current build is best for local personal libraries and design-asset workflows involving PNG/JPG textures, overlays, effects, stickers, paper scraps, and similar packs.

Crate does **not** include third-party design assets. You import assets you own or have permission to use.

## Requirements

- macOS 14 or newer
- Xcode 26 or newer, or Xcode Command Line Tools with the macOS 26 SDK
- Node.js only if you want to run the MCP wrapper

Crate uses macOS 26 Liquid Glass APIs behind runtime availability checks. That means the app can run on older supported macOS versions, but building from source needs a toolchain that knows the macOS 26 SDK symbols.

## Quick Start

```bash
git clone <repo-url> crate
cd crate
./script/verify.sh
./script/build_and_run.sh
```

`verify.sh` builds Crate, runs unit tests, imports the sample pack into a temporary library, searches it, adds assets to the cart, creates a collection, exports folder/zip, and validates the result. No personal asset library required.

On first launch, choose or create a managed library. Crate suggests:

```text
~/Documents/DesignAssets
```

The managed library is separate from the source folders you import. Crate copies assets into the library and does not mutate the original folders.

## Sample Pack

The repo includes a tiny generated sample pack so new contributors can test the full import loop immediately:

![Sample paper texture](Samples/Crate%20Sample%20Paper%20Textures/paper-speckle.png)

```text
Samples/Crate Sample Paper Textures/
  paper-speckle.png
  paper-edge-alpha.png
  fold-overlay.png
  fold-overlay.jpg
  ignored-note.txt
```

The PNG/JPG `fold-overlay` pair verifies variant grouping; `ignored-note.txt` verifies ignored-file reporting.

## Library Layout

```text
DesignAssets/
  00_Inbox/
  10_Library/packs/
  20_Collections/
  30_Exports/
  _database/
  _thumbnails/
  _manifests/
```

## Import Assets

Use **Import Folder** for normal asset packs. Crate supports PNG, JPG, and JPEG files. Hidden files and non-image files are ignored.

```bash
./script/cratectl.sh analyze-folder "/path/to/Asset Pack"
./script/cratectl.sh import-folder "/path/to/Asset Pack"
./script/cratectl.sh import-folder "/path/to/Asset Pack" --kind overlay --material plastic --subtype plastic-wrap
```

Try the repo-owned sample pack:

```bash
./script/cratectl.sh import-folder "Samples/Crate Sample Paper Textures" --source "Crate Sample"
./script/cratectl.sh search paper --limit 3
```

Optional import hints:

- `--kind`: `texture`, `overlay`, `sticker`
- `--material`: `paper`, `plastic`, `ink`, `tape`, etc.
- `--subtype`: stable slug such as `torn-paper`
- `--display-name`: human-readable pack name
- `--source`: vendor/source label
- `--pack-id`: stable pack id
- `--short-code`: filename prefix

## Optional Presets

Crate includes optional preset rules for three Resource Boy packs. The assets are not included. If you own those packs, place their folders in `~/Downloads`, or set `CRATE_RESOURCE_BOY_ROOT` to a parent folder containing:

```text
Resource Boy - Ransom Note Letters/
Resource Boy - Torn Paper Textures/
Resource Boy - Plastic Wrap Textures/
```

```bash
CRATE_RESOURCE_BOY_ROOT="/path/to/preset-parent" ./script/build_and_run.sh
```

## App Features

- Managed library picker and reconnect flow
- Import review before committing a folder
- Normalized asset names and per-pack manifests
- SQLite metadata store
- Cached thumbnails
- Sidebar filters for packs, kinds, materials, uses, visual tags, collections, and smart collections
- Search by filename, normalized name, pack, and tags
- Shuffle discovery
- Similar assets by tag and geometry overlap
- Duplicate scanning
- Visual analysis tags for color, brightness, contrast, orientation, transparency, and edge density
- Inspector preview with pan, zoom, rotation, variants, background switching, and blend modes
- Shared cart, collections, folder export, and zip export
- CLI and MCP wrapper for agentic workflows

## Keyboard Shortcuts

- `Cmd-O`: Import Folder
- `Shift-Cmd-I`: Import Presets
- `Option-Cmd-R`: Shuffle 12
- `Cmd-R`: Reload Library
- `Cmd-F`: Search
- `Shift-Cmd-E`: Export Cart
- `Shift-Cmd-D`: Scan Duplicates
- `Shift-Cmd-A`: Analyze Visual Tags
- `Option-Cmd-L`: Reconnect Library
- `Option-Cmd-M`: Move Library
- `Option-Cmd-V`: Validate Library

## CLI

The CLI uses Crate's saved library path, then falls back to `~/Documents/DesignAssets`. Pass `--library <path>` when you want a specific library.

```bash
./script/cratectl.sh status
./script/cratectl.sh status --json
./script/cratectl.sh packs
./script/cratectl.sh packs --json
./script/cratectl.sh search "paper" --limit 12
./script/cratectl.sh search "plastic" --kind overlay --tag material:plastic --alpha
./script/cratectl.sh show <asset-id>
./script/cratectl.sh show <asset-id> --json
./script/cratectl.sh similar <asset-id> --limit 8
./script/cratectl.sh remove-pack <pack-id> --yes
./script/cratectl.sh library validate
./script/cratectl.sh library validate --json
```

Cart and collection flow:

```bash
./script/cratectl.sh cart clear
./script/cratectl.sh cart add-search "scribble" --limit 6
./script/cratectl.sh cart list
./script/cratectl.sh collection create "Moodboard Picks" --from-cart
./script/cratectl.sh cart export-folder
./script/cratectl.sh cart export-zip
```

Library migration:

```bash
./script/cratectl.sh library move "/Volumes/YourSSD/DesignAssets" --yes
./script/cratectl.sh --library "/old/path/DesignAssets" library move "/Volumes/YourSSD/DesignAssets" --yes --save
```

If Crate is already open while the CLI changes the cart or collections, use Reload in the app or `Cmd-R`.

## MCP Wrapper

`script/crate-mcp.mjs` exposes a small stdio MCP server over `cratectl`:

- `analyze_folder`
- `import_folder`
- `search_assets`
- `add_to_cart`
- `create_collection`
- `export_cart`

Run the MCP wrapper from the repo root:

```bash
node "$(pwd)/script/crate-mcp.mjs"
```

Each tool accepts an optional `library` argument. If omitted, Crate uses the saved/default library.

## Package The App

For local personal use:

```bash
./script/package_app.sh --verify
```

To install into `/Applications`:

```bash
./script/package_app.sh --install --verify
```

The scripts sign locally, preferring `CRATE_CODESIGN_IDENTITY` when set, then any Apple Development identity, then ad-hoc signing.

Useful environment variables:

```bash
CRATE_BUNDLE_ID="com.example.crate" ./script/package_app.sh
CRATE_CODESIGN_IDENTITY="Apple Development: Your Name (...)" ./script/package_app.sh
CRATE_VERSION="0.1.0" CRATE_BUILD="42" ./script/package_app.sh
```

Public distribution requires Developer ID signing and notarization.

## Development

```bash
swift build
swift test
./script/verify.sh
./script/build_and_run.sh --verify
```

Useful docs:

- [Getting Started](docs/GETTING_STARTED.md)
- [Importing Assets](docs/IMPORTING.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Releasing](docs/RELEASING.md)

Code organization:

- `Sources/Crate/App`: app entry and commands
- `Sources/Crate/Models`: data models and import descriptors
- `Sources/Crate/Stores`: app state, SQLite wrapper, persistence
- `Sources/Crate/Services`: import, thumbnails, exports, duplicate detection, visual analysis, maintenance
- `Sources/Crate/Views`: SwiftUI views and reusable view components
- `Sources/Crate/Support`: CLI, MCP-adjacent support, small utilities

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).
