//
//  AssetRemovalService.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import Foundation

enum AssetRemovalService {
    static func remove(
        assetIDs: Set<String>,
        store: AssetStore,
        paths: LibraryPaths,
        deleteFromVault: Bool = true
    ) throws -> AssetRemovalResult {
        let allAssets = try store.fetchAssets()
        let packs = try store.fetchPacks()
        let selectedAssets = allAssets.filter { assetIDs.contains($0.id) }

        guard !selectedAssets.isEmpty else {
            throw AssetRemovalError.noMatchingAssets
        }

        let selectedIDs = Set(selectedAssets.map(\.id))
        let affectedPackIDs = Set(selectedAssets.map(\.packID))
        let assetsByPack = Dictionary(grouping: allAssets, by: \.packID)
        let removedPackIDs = Set(affectedPackIDs.filter { packID in
            let packAssets = assetsByPack[packID] ?? []
            return !packAssets.isEmpty && packAssets.allSatisfy { selectedIDs.contains($0.id) }
        })

        let variantURLs = selectedAssets.flatMap { $0.variants.map(\.fileURL) }
        let thumbnailURLs = selectedAssets.compactMap(\.thumbnailURL)
        let remainingAssets = allAssets.filter { !selectedIDs.contains($0.id) }

        try store.deleteAssets(ids: selectedIDs)

        let fileManager = FileManager.default
        var removedFileCount = 0
        var removedThumbnailCount = 0
        var removedPathCount = 0

        for packID in removedPackIDs {
            let urls = deleteFromVault
                ? [paths.packLibraryURL(packID), paths.packManifestURL(packID)]
                : [paths.packManifestURL(packID)]
            for url in urls where fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
                removedPathCount += 1
            }
        }

        if deleteFromVault {
            for url in variantURLs where !removedPackIDs.contains(packID(containing: url, paths: paths)) {
                if fileManager.fileExists(atPath: url.path) {
                    try fileManager.removeItem(at: url)
                    removedFileCount += 1
                    removeEmptyParents(startingAt: url.deletingLastPathComponent(), stopAt: paths.packs, fileManager: fileManager)
                }
            }
        }

        for url in thumbnailURLs where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
            removedThumbnailCount += 1
        }

        for packID in affectedPackIDs.subtracting(removedPackIDs) {
            guard let pack = packs.first(where: { $0.id == packID }) else { continue }
            let packAssets = remainingAssets.filter { $0.packID == packID }
            try writeManifest(pack: pack, assets: packAssets, paths: paths)
        }

        return AssetRemovalResult(
            removedAssetCount: selectedAssets.count,
            removedFileCount: removedFileCount,
            removedThumbnailCount: removedThumbnailCount,
            removedPackCount: removedPackIDs.count,
            removedPackPathCount: removedPathCount
        )
    }

    private static func packID(containing url: URL, paths: LibraryPaths) -> String {
        let relative = url.relativePath(from: paths.packs)
        return relative.split(separator: "/").first.map(String.init) ?? ""
    }

    private static func removeEmptyParents(startingAt directory: URL, stopAt stopDirectory: URL, fileManager: FileManager) {
        var current = directory.standardizedFileURL
        let stopPath = stopDirectory.standardizedFileURL.path

        while current.path.hasPrefix(stopPath), current.path != stopPath {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: current.path), contents.isEmpty else { return }
            try? fileManager.removeItem(at: current)
            current.deleteLastPathComponent()
        }
    }

    private static func writeManifest(pack: AssetPack, assets: [DesignAsset], paths: LibraryPaths) throws {
        let packRoot = paths.packLibraryURL(pack.id)
        let manifestAssets = assets.map { asset in
            ManifestAsset(
                id: asset.id,
                displayName: asset.displayName,
                originalFiles: asset.variants.map(\.originalFileName),
                variants: Dictionary(uniqueKeysWithValues: asset.variants.map {
                    ($0.role.rawValue, $0.fileURL.relativePath(from: packRoot))
                }),
                tags: Dictionary(grouping: asset.tags, by: \.namespace)
                    .mapValues { Array(Set($0.map(\.value))).sorted() }
            )
        }

        let manifest = PackManifest(
            schemaVersion: 1,
            packID: pack.id,
            displayName: pack.displayName,
            source: pack.source,
            importedAt: pack.importedAt,
            importerVersion: "1.0",
            assetCount: assets.count,
            rules: ["updated_by": "asset_removal"],
            assets: manifestAssets
        )

        let data = try DateCoding.encoder.encode(manifest)
        try data.write(to: paths.packManifestURL(pack.id), options: [.atomic])
    }
}

struct AssetRemovalResult: Codable, Hashable {
    let removedAssetCount: Int
    let removedFileCount: Int
    let removedThumbnailCount: Int
    let removedPackCount: Int
    let removedPackPathCount: Int
}

enum AssetRemovalError: Error, LocalizedError {
    case noMatchingAssets

    var errorDescription: String? {
        switch self {
        case .noMatchingAssets: "No matching assets to remove."
        }
    }
}
