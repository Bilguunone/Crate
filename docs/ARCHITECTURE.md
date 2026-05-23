# Architecture

Crate is a SwiftPM macOS app with one executable target. The app and CLI share the same models, services, and SQLite store.

## Main Layers

- `App`: app entry point, scenes, app commands, and menu shortcuts.
- `Models`: plain data types, import presets, generic import descriptors, and manifest structures.
- `Stores`: observable app state, SQLite persistence, and state-focused extensions.
- `Services`: file import, thumbnail generation, export, visual analysis, duplicate detection, library migration, and maintenance.
- `Views`: SwiftUI screens, grid cells, sidebar components, inspector pieces, and preview controls.
- `Support`: CLI dispatcher, CLI command families, parsing, output, and small utility types.

## Data Flow

1. The user chooses a library root.
2. `LibraryManager` resolves and persists the selected root.
3. `LibraryPaths` derives database, thumbnail, manifest, pack, collection, and export locations.
4. `AssetImporter` copies images into `10_Library/packs`, generates thumbnails, creates pack manifests, and returns model records.
5. `AssetStore` writes durable metadata to SQLite.
6. `AppModel` loads records, builds browsing caches, and drives SwiftUI views.
7. CLI and MCP commands call the same store/services as the app.

## Library Safety

Crate copies imported files into a managed library and does not mutate source folders. Pack removal deletes the managed pack files, thumbnails, manifests, and SQLite rows for that pack.

The app should never create fake empty libraries for missing external drives. Missing external libraries should route through reconnect/move/validate flows.
