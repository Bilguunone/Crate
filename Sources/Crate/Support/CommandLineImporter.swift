//
//  CommandLineImporter.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-22.
//

import Foundation

enum CommandLineImporter {
    static func runIfRequested() -> Int? {
        let arguments = CommandLine.arguments
        if arguments.dropFirst().first == "cratectl" {
            return CrateCLI(arguments: Array(arguments.dropFirst(2))).run()
        }

        if let index = arguments.firstIndex(of: "--import-folder-to"),
           arguments.indices.contains(index + 2) {
            return importFolder(libraryRoot: arguments[index + 1], source: arguments[index + 2])
        }

        guard let index = arguments.firstIndex(of: "--import-presets-to"),
              arguments.indices.contains(index + 1)
        else { return nil }

        return importPresets(libraryRoot: arguments[index + 1])
    }

    private static func importPresets(libraryRoot: String) -> Int {
        let root = URL(fileURLWithPath: libraryRoot, isDirectory: true)

        do {
            let paths = try LibraryManager.prepareLibrary(at: root, save: false)
            let store = try AssetStore(databaseURL: paths.databaseURL)
            let importer = AssetImporter(paths: paths)

            for preset in ImportPresetCatalog.resourceBoy {
                let result = try importer.importPreset(preset)
                try store.replacePack(result.pack, assets: result.assets)
                print("imported \(result.pack.id): \(result.assets.count)")
            }

            let packs = try store.fetchPacks()
            let assets = try store.fetchAssets()
            print("packs: \(packs.count)")
            print("assets: \(assets.count)")
            print("plastic grouped assets: \(assets.filter { $0.packID == "resource-boy-plastic-wrap-textures" }.count)")
            return 0
        } catch {
            fputs("Crate import failed: \(error.localizedDescription)\n", stderr)
            return 1
        }
    }

    private static func importFolder(libraryRoot: String, source: String) -> Int {
        let root = URL(fileURLWithPath: libraryRoot, isDirectory: true)
        let sourceURL = URL(fileURLWithPath: source, isDirectory: true)

        do {
            let paths = try LibraryManager.prepareLibrary(at: root, save: false)
            let store = try AssetStore(databaseURL: paths.databaseURL)
            let importer = AssetImporter(paths: paths)
            let result = try importer.importGenericFolder(sourceURL)
            try store.replacePack(result.pack, assets: result.assets)
            print("imported \(result.pack.id): \(result.assets.count)")
            print("variants: \(result.assets.reduce(0) { $0 + $1.variants.count })")
            return 0
        } catch {
            fputs("Crate folder import failed: \(error.localizedDescription)\n", stderr)
            return 1
        }
    }
}
