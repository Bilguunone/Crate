# Getting Started

This guide verifies Crate without needing your own design assets.

## Requirements

- macOS 14 or newer
- Xcode 26 or newer, or Xcode Command Line Tools with the macOS 26 SDK
- Node.js only if you want to run the MCP wrapper

Crate uses macOS 26 Liquid Glass APIs behind runtime availability checks. Building from source needs the macOS 26 SDK even though the app keeps fallbacks for older supported macOS versions.

## 1. Verify The Repo

```bash
./script/verify.sh
```

This builds Crate, runs unit tests, imports the sample pack into a temporary library, searches it, carts assets, creates a collection, exports folder/zip, and validates the library.

## 2. Run The App

```bash
./script/build_and_run.sh
```

Choose or create a library when prompted.

## 3. Import The Sample Pack

Use the app's Import Folder action and choose:

```text
Samples/Crate Sample Paper Textures
```

Or use the CLI:

```bash
./script/cratectl.sh import-folder "Samples/Crate Sample Paper Textures" --source "Crate Sample"
```

## 4. Try The Core Loop

- Search for `paper`.
- Add two assets to the cart.
- Save the cart as a collection.
- Export the cart as a folder or zip.
- Run `./script/cratectl.sh library validate`.

Now you have tested the same loop Crate uses for real asset packs.
