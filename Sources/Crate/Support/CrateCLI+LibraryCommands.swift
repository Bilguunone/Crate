//
//  CrateCLI+LibraryCommands.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import Foundation

extension CrateCLI {
    func status(_ context: CLIContext, json: Bool) throws {
        let packs = try context.store.fetchPacks()
        let assets = try context.store.fetchAssets()
        let cart = try context.store.fetchCart()
        let collections = try context.store.fetchCollections()
        let status = CLIStatus(
            library: context.paths.root.path,
            packs: packs.count,
            assets: assets.count,
            cart: cart.count,
            collections: collections.count
        )

        if json {
            try printJSON(status)
            return
        }
        print("library: \(context.paths.root.path)")
        print("packs: \(packs.count)")
        print("assets: \(assets.count)")
        print("cart: \(cart.count)")
        print("collections: \(collections.count)")
    }

    func packs(_ context: CLIContext, json: Bool) throws {
        let packs = try context.store.fetchPacks()
        if json {
            try printJSON(packs.map(CLIPackRecord.init(pack:)))
            return
        }
        if packs.isEmpty {
            print("No packs imported.")
            return
        }
        for pack in packs {
            print("\(pack.id)\t\(pack.assetCount)\t\(pack.displayName)")
        }
    }

    func importFolder(_ context: CLIContext, parser: inout CLIParser) throws {
        guard let path = parser.next() else {
            throw CLIError.message("usage: cratectl import-folder <path> [--kind k] [--material m] [--subtype s] [--display-name name] [--source name]")
        }
        let sourceURL = URL(fileURLWithPath: path, isDirectory: true)
        let options = GenericImportOptions(parser: &parser)
        let importer = AssetImporter(paths: context.paths)
        let result = try importer.importGenericFolder(sourceURL, options: options)
        try context.store.replacePack(result.pack, assets: result.assets)
        print("imported \(result.pack.id): \(result.assets.count)")
    }

    func analyzeFolder(parser: inout CLIParser, json: Bool) throws {
        guard let path = parser.next() else {
            throw CLIError.message("usage: cratectl analyze-folder <path> [--json] [--kind k] [--material m] [--subtype s] [--display-name name] [--source name]")
        }

        let json = json || parser.hasFlag("--json")
        let sourceURL = URL(fileURLWithPath: path, isDirectory: true)
        let options = GenericImportOptions(parser: &parser)
        let analysis = try ImportFolderAnalyzer.analyze(sourceURL: sourceURL, options: options)

        if json {
            try printJSON(analysis)
        } else {
            print("source: \(analysis.sourcePath)")
            print("display: \(analysis.displayName)")
            print("pack_id: \(analysis.packID)")
            print("suggested: kind=\(analysis.inferredKind) material=\(analysis.inferredMaterial) subtype=\(analysis.inferredSubtype)")
            print("images: \(analysis.imageCount)")
            print("ignored: \(analysis.ignoredFileCount)")
            print("variant_groups: \(analysis.variantGroupCount)")
            print("multi_variant_groups: \(analysis.multiVariantGroupCount)")
            if !analysis.riskyDuplicateBasenames.isEmpty {
                print("duplicate_basenames_across_folders: \(analysis.riskyDuplicateBasenames.joined(separator: ", "))")
            }
            print("extensions:")
            for key in analysis.extensionCounts.keys.sorted() {
                print("  \(key): \(analysis.extensionCounts[key] ?? 0)")
            }
            print("top_folders:")
            for key in analysis.topLevelFolders.keys.sorted() {
                print("  \(key): \(analysis.topLevelFolders[key] ?? 0)")
            }
            print("sample_plan:")
            for sample in analysis.samplePlans {
                print("  \(sample.assetID)\t\(sample.variantCount)\t\(sample.displayName)")
            }
            print("suggested_command:")
            print("  \(analysis.suggestedCommand)")
        }
    }

    func removePack(_ context: CLIContext, parser: inout CLIParser, json: Bool) throws {
        guard let packID = parser.next() else {
            throw CLIError.message("usage: cratectl remove-pack <pack-id> --yes")
        }
        guard parser.hasFlag("--yes") else {
            throw CLIError.message("remove-pack is destructive; rerun with --yes")
        }

        let result = try PackRemovalService.remove(packID: packID, store: context.store, paths: context.paths)
        if json {
            try printJSON(result)
        } else {
            print("removed \(result.packID): \(result.removedAssetCount) assets, \(result.removedThumbnailCount) thumbnails")
            for path in result.removedPaths {
                print(path)
            }
        }
    }

    func duplicates(_ context: CLIContext, parser: inout CLIParser, json: Bool) throws {
        let threshold = parser.intOption("--near-threshold") ?? 4
        let report = DuplicateDetectionService.scan(assets: try context.store.fetchAssets(), nearThreshold: threshold)

        if json {
            try printJSON(report)
            return
        }

        print("scanned_variants: \(report.scannedVariantCount)")
        print("exact_file_groups: \(report.exactFileGroups.count)")
        print("same_image_groups: \(report.sameImageGroups.count)")
        print("jpg_png_variant_groups: \(report.jpgPngVariantGroups.count)")
        print("near_duplicate_groups: \(report.nearDuplicateGroups.count)")
        printDuplicateGroups("exact", report.exactFileGroups)
        printDuplicateGroups("same-image", report.sameImageGroups)
        printDuplicateGroups("near", report.nearDuplicateGroups)
    }

    func analyzeVisualTags(_ context: CLIContext, json: Bool) throws {
        let report = VisualAnalysisService.tagUpdates(for: try context.store.fetchAssets())
        try context.store.replaceComputedTags(report.updates)

        if json {
            try printJSON(report)
            return
        }

        print("analyzed_assets: \(report.analyzedAssetCount)")
        print("failed_assets: \(report.failedAssetCount)")
        print("written_tags: \(report.writtenTagCount)")
    }

    func repairThumbnails(_ context: CLIContext, json: Bool) throws {
        let assets = try context.store.fetchAssets()
        var updates: [String: URL?] = [:]
        var removedStaleCount = 0
        var regeneratedCount = 0
        var failedAssetIDs: [String] = []

        for asset in assets {
            guard let primary = asset.primaryVariant else {
                updates[asset.id] = nil
                failedAssetIDs.append(asset.id)
                continue
            }

            let expectedURL = ThumbnailService.thumbnailURL(
                for: asset.id,
                in: context.paths,
                preservesAlpha: primary.hasAlpha
            )
            let hadExpectedThumbnail = FileManager.default.fileExists(atPath: expectedURL.path)

            guard let newURL = try ThumbnailService.generateThumbnail(
                sourceURL: primary.fileURL,
                assetID: asset.id,
                paths: context.paths,
                preservesAlpha: primary.hasAlpha
            ) else {
                updates[asset.id] = nil
                failedAssetIDs.append(asset.id)
                continue
            }

            updates[asset.id] = newURL
            if !hadExpectedThumbnail {
                regeneratedCount += 1
            }

            if let oldURL = asset.thumbnailURL,
               oldURL.standardizedFileURL.path != newURL.standardizedFileURL.path,
               FileManager.default.fileExists(atPath: oldURL.path) {
                try? FileManager.default.removeItem(at: oldURL)
                removedStaleCount += 1
            }
        }

        try context.store.replaceThumbnailPaths(updates)
        let report = CLIThumbnailRepairReport(
            scannedAssets: assets.count,
            updatedAssets: updates.count,
            regeneratedThumbnails: regeneratedCount,
            removedStaleThumbnails: removedStaleCount,
            failedAssetIDs: failedAssetIDs
        )

        if json {
            try printJSON(report)
            return
        }

        print("scanned_assets: \(report.scannedAssets)")
        print("updated_assets: \(report.updatedAssets)")
        print("regenerated_thumbnails: \(report.regeneratedThumbnails)")
        print("removed_stale_thumbnails: \(report.removedStaleThumbnails)")
        print("failed_assets: \(report.failedAssetIDs.count)")
    }

    func library(libraryRoot: URL, explicitLibrary: Bool, parser: inout CLIParser, json: Bool) throws {
        guard let subcommand = parser.next() else {
            throw CLIError.message("usage: cratectl [--library <path>] library validate [--json] | library move <destination-folder> --yes [--save] [--json]")
        }

        switch subcommand {
        case "validate":
            let report = try LibraryMaintenanceService.validateLibrary(at: libraryRoot)
            if json {
                try printJSON(report)
            } else {
                printLibraryValidation(report)
            }
        case "move":
            guard let destinationPath = parser.next() else {
                throw CLIError.message("usage: cratectl [--library <path>] library move <destination-folder> --yes [--save]")
            }
            guard parser.hasFlag("--yes") else {
                throw CLIError.message("library move is destructive; rerun with --yes")
            }
            let saveMovedRoot = parser.hasFlag("--save")
                || !explicitLibrary
                || LibraryManager.savedRoot()?.standardizedFileURL.path == libraryRoot.standardizedFileURL.path

            let selectedDestination = URL(fileURLWithPath: destinationPath, isDirectory: true)
            let destinationRoot = LibraryMaintenanceService.proposedDestinationRoot(
                selectedURL: selectedDestination,
                currentRoot: libraryRoot
            )
            let result = try LibraryMaintenanceService.moveLibrary(from: libraryRoot, to: destinationRoot)
            if saveMovedRoot {
                LibraryManager.saveRoot(result.destinationRoot)
            }

            if json {
                try printJSON(CLILibraryMigrationRecord(result: result))
            } else {
                print("moved: \(result.sourceRoot.path) -> \(result.destinationRoot.path)")
                print("removed_source: \(result.removedSource ? "yes" : "no")")
                printLibraryValidation(result.validationReport)
            }
        default:
            throw CLIError.message("Unknown library command: \(subcommand)")
        }
    }
}
