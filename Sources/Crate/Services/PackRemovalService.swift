//
//  PackRemovalService.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import Foundation

enum PackRemovalService {
    static func remove(
        packID: String,
        store: AssetStore,
        paths: LibraryPaths,
        deleteFromVault: Bool = true
    ) throws -> PackRemovalResult {
        let packs = try store.fetchPacks()
        guard let pack = packs.first(where: { $0.id == packID }) else {
            throw PackRemovalError.packNotFound(packID)
        }

        let assets = try store.fetchAssets().filter { $0.packID == packID }
        let thumbnailURLs = assets.compactMap(\.thumbnailURL)
        try store.deletePack(id: packID)

        let fileManager = FileManager.default
        var removedPaths: [String] = []
        let urls = deleteFromVault
            ? [paths.packLibraryURL(packID), paths.packManifestURL(packID)]
            : [paths.packManifestURL(packID)]
        for url in urls {
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
                removedPaths.append(url.path)
            }
        }

        var removedThumbnails = 0
        for url in thumbnailURLs where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
            removedThumbnails += 1
        }

        return PackRemovalResult(
            packID: pack.id,
            displayName: pack.displayName,
            removedAssetCount: assets.count,
            removedThumbnailCount: removedThumbnails,
            removedPaths: removedPaths
        )
    }
}

struct PackRemovalResult: Codable {
    let packID: String
    let displayName: String
    let removedAssetCount: Int
    let removedThumbnailCount: Int
    let removedPaths: [String]
}

enum PackRemovalError: Error, LocalizedError {
    case packNotFound(String)

    var errorDescription: String? {
        switch self {
        case .packNotFound(let packID): "Pack not found: \(packID)"
        }
    }
}
