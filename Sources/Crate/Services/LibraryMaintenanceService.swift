//
//  LibraryMaintenanceService.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import Foundation

enum LibraryMaintenanceError: LocalizedError {
    case sourceMissing(String)
    case destinationMatchesSource(String)
    case destinationInsideSource(String)
    case destinationNotEmpty(String)
    case migrationValidationFailed(LibraryValidationReport)

    var errorDescription: String? {
        switch self {
        case .sourceMissing(let path):
            "Library source does not exist: \(path)"
        case .destinationMatchesSource(let path):
            "The destination is already the current library: \(path)"
        case .destinationInsideSource(let path):
            "Choose a destination outside the current library. This one is inside it: \(path)"
        case .destinationNotEmpty(let path):
            "Destination folder is not empty: \(path)"
        case .migrationValidationFailed(let report):
            "Moved copy did not validate. \(report.summary)"
        }
    }
}

enum LibraryMaintenanceService {
    static func proposedDestinationRoot(selectedURL: URL, currentRoot: URL) -> URL {
        let selected = selectedURL.standardizedFileURL
        let currentName = currentRoot.lastPathComponent.isEmpty ? "DesignAssets" : currentRoot.lastPathComponent
        if isVolumeRoot(selected) {
            return selected.appendingPathComponent(currentName, isDirectory: true)
        }
        return selected
    }

    static func validateLibrary(at root: URL) throws -> LibraryValidationReport {
        let paths = LibraryPaths(root: root)
        let fileManager = FileManager.default
        let requiredDirectories: [(String, URL)] = [
            ("00_Inbox", paths.inbox),
            ("10_Library/packs", paths.packs),
            ("20_Collections", paths.collections),
            ("30_Exports", paths.exports),
            ("_database", paths.databaseDirectory),
            ("_thumbnails", paths.thumbnails),
            ("_manifests", paths.manifests)
        ]

        let missingDirectories = requiredDirectories.compactMap { label, url in
            isDirectory(url, fileManager: fileManager) ? nil : label
        }

        let databaseExists = fileManager.fileExists(atPath: paths.databaseURL.path)
        guard databaseExists else {
            return LibraryValidationReport(
                root: root,
                databaseExists: false,
                missingDirectories: missingDirectories,
                packCount: 0,
                assetCount: 0,
                variantCount: 0,
                missingVariantFileCount: 0,
                missingThumbnailCount: 0,
                missingManifestCount: 0
            )
        }

        let store = try AssetStore(databaseURL: paths.databaseURL)
        let packs = try store.fetchPacks()
        let assets = try store.fetchAssets()
        let variants = assets.flatMap(\.variants)
        let rootPath = root.standardizedFileURL.path + "/"
        let missingVariantFileCount = variants.filter {
            !$0.fileURL.standardizedFileURL.path.hasPrefix(rootPath)
                || !fileManager.fileExists(atPath: $0.fileURL.path)
        }.count
        let missingThumbnailCount = assets.compactMap(\.thumbnailURL).filter {
            !$0.standardizedFileURL.path.hasPrefix(rootPath)
                || !fileManager.fileExists(atPath: $0.path)
        }.count
        let missingManifestCount = packs.filter { !fileManager.fileExists(atPath: paths.packManifestURL($0.id).path) }.count

        return LibraryValidationReport(
            root: root,
            databaseExists: true,
            missingDirectories: missingDirectories,
            packCount: packs.count,
            assetCount: assets.count,
            variantCount: variants.count,
            missingVariantFileCount: missingVariantFileCount,
            missingThumbnailCount: missingThumbnailCount,
            missingManifestCount: missingManifestCount
        )
    }

    static func moveLibrary(from sourceRoot: URL, to destinationRoot: URL) throws -> LibraryMigrationResult {
        let fileManager = FileManager.default
        let source = sourceRoot.standardizedFileURL
        let destination = destinationRoot.standardizedFileURL

        guard isDirectory(source, fileManager: fileManager) else {
            throw LibraryMaintenanceError.sourceMissing(source.path)
        }
        guard source.path != destination.path else {
            throw LibraryMaintenanceError.destinationMatchesSource(destination.path)
        }
        guard !destination.path.hasPrefix(source.path + "/") else {
            throw LibraryMaintenanceError.destinationInsideSource(destination.path)
        }

        let parent = destination.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)

        if fileManager.fileExists(atPath: destination.path) {
            if isDirectory(destination, fileManager: fileManager), try isDirectoryEmpty(destination, fileManager: fileManager) {
                try fileManager.removeItem(at: destination)
            } else {
                throw LibraryMaintenanceError.destinationNotEmpty(destination.path)
            }
        }

        let temporaryDestination = parent.appendingPathComponent(".\(destination.lastPathComponent).migrating-\(UUID().uuidString)", isDirectory: true)
        if fileManager.fileExists(atPath: temporaryDestination.path) {
            try fileManager.removeItem(at: temporaryDestination)
        }

        try fileManager.copyItem(at: source, to: temporaryDestination)
        try fileManager.moveItem(at: temporaryDestination, to: destination)

        let destinationPaths = LibraryPaths(root: destination)
        let store = try AssetStore(databaseURL: destinationPaths.databaseURL)
        try store.rewriteStoredPaths(from: source, to: destination)

        let report = try validateLibrary(at: destination)
        guard report.isUsable else {
            throw LibraryMaintenanceError.migrationValidationFailed(report)
        }

        let removedSource: Bool
        do {
            try fileManager.removeItem(at: source)
            removedSource = true
        } catch {
            removedSource = false
        }

        return LibraryMigrationResult(
            sourceRoot: source,
            destinationRoot: destination,
            validationReport: report,
            removedSource: removedSource
        )
    }

    private static func isVolumeRoot(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        guard path.hasPrefix("/Volumes/") else { return false }
        let remainder = String(path.dropFirst("/Volumes/".count))
        return !remainder.isEmpty && !remainder.contains("/")
    }

    private static func isDirectory(_ url: URL, fileManager: FileManager) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private static func isDirectoryEmpty(_ url: URL, fileManager: FileManager) throws -> Bool {
        let contents = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        return contents.isEmpty
    }
}
