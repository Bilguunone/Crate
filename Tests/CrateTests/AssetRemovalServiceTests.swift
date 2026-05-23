//
//  AssetRemovalServiceTests.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import XCTest
@testable import Crate

final class AssetRemovalServiceTests: XCTestCase {
    func testPartialAssetRemovalDeletesManagedFilesAndKeepsRemainingPackData() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        try seedPack(fixture, assetIDs: ["asset-a", "asset-b"])
        try fixture.store.saveCart([
            CartItem(id: "cart-a", assetID: "asset-a", addedAt: Date(timeIntervalSince1970: 1)),
            CartItem(id: "cart-b", assetID: "asset-b", addedAt: Date(timeIntervalSince1970: 2))
        ])
        try fixture.store.saveCollection(
            AssetCollection(
                id: "collection-a",
                name: "Working Set",
                coverAssetID: "asset-a",
                createdAt: Date(timeIntervalSince1970: 3),
                assetIDs: ["asset-a", "asset-b"]
            )
        )
        try fixture.store.setFavorite(assetID: "asset-a", isFavorite: true)
        try fixture.store.saveUserTag(assetID: "asset-a", namespace: "mood", value: "doomed")
        try fixture.store.saveUserTag(assetID: "asset-b", namespace: "mood", value: "keeper")

        let result = try AssetRemovalService.remove(assetIDs: ["asset-a"], store: fixture.store, paths: fixture.paths)

        XCTAssertEqual(result.removedAssetCount, 1)
        XCTAssertEqual(result.removedFileCount, 1)
        XCTAssertEqual(result.removedThumbnailCount, 1)
        XCTAssertEqual(result.removedPackCount, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.assetFileURL("asset-a").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.thumbnailURL("asset-a").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.assetFileURL("asset-b").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.thumbnailURL("asset-b").path))

        let packs = try fixture.store.fetchPacks()
        XCTAssertEqual(packs.count, 1)
        XCTAssertEqual(packs.first?.assetCount, 1)
        XCTAssertEqual(try fixture.store.fetchAssets().map(\.id), ["asset-b"])
        XCTAssertEqual(try fixture.store.fetchCart().map(\.assetID), ["asset-b"])
        XCTAssertEqual(try fixture.store.fetchFavoriteAssetIDs(), [])

        let collections = try fixture.store.fetchCollections()
        XCTAssertEqual(collections.count, 1)
        XCTAssertEqual(collections.first?.coverAssetID, nil)
        XCTAssertEqual(collections.first?.assetIDs, ["asset-b"])
        XCTAssertEqual(try fixture.store.fetchUserTagFacets().map(\.value), ["keeper"])

        let manifestData = try Data(contentsOf: fixture.paths.packManifestURL(fixture.packID))
        let manifest = try DateCoding.decoder.decode(PackManifest.self, from: manifestData)
        XCTAssertEqual(manifest.assetCount, 1)
        XCTAssertEqual(manifest.assets.map(\.id), ["asset-b"])
    }

    func testAssetRemovalCanKeepVaultFiles() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        try seedPack(fixture, assetIDs: ["asset-a", "asset-b"])

        let result = try AssetRemovalService.remove(
            assetIDs: ["asset-a"],
            store: fixture.store,
            paths: fixture.paths,
            deleteFromVault: false
        )

        XCTAssertEqual(result.removedAssetCount, 1)
        XCTAssertEqual(result.removedFileCount, 0)
        XCTAssertEqual(result.removedThumbnailCount, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.assetFileURL("asset-a").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.thumbnailURL("asset-a").path))
        XCTAssertEqual(try fixture.store.fetchAssets().map(\.id), ["asset-b"])

        let manifestData = try Data(contentsOf: fixture.paths.packManifestURL(fixture.packID))
        let manifest = try DateCoding.decoder.decode(PackManifest.self, from: manifestData)
        XCTAssertEqual(manifest.assets.map(\.id), ["asset-b"])
    }

    func testRemovingEveryAssetDeletesPackShellAndDatabaseRows() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        try seedPack(fixture, assetIDs: ["asset-a", "asset-b"])

        let result = try AssetRemovalService.remove(assetIDs: ["asset-a", "asset-b"], store: fixture.store, paths: fixture.paths)

        XCTAssertEqual(result.removedAssetCount, 2)
        XCTAssertEqual(result.removedPackCount, 1)
        XCTAssertEqual(try fixture.store.fetchAssets(), [])
        XCTAssertEqual(try fixture.store.fetchPacks(), [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.paths.packLibraryURL(fixture.packID).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.paths.packManifestURL(fixture.packID).path))
    }

    private func makeFixture() throws -> RemovalFixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CrateRemovalTests-\(UUID().uuidString)", isDirectory: true)
        let paths = try LibraryManager.prepareLibrary(at: root, save: false)
        let store = try AssetStore(databaseURL: paths.databaseURL)
        return RemovalFixture(root: root, paths: paths, store: store)
    }

    private func seedPack(_ fixture: RemovalFixture, assetIDs: [String]) throws {
        try FileManager.default.createDirectory(
            at: fixture.assetDirectory,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: fixture.paths.thumbnails,
            withIntermediateDirectories: true
        )

        for assetID in assetIDs {
            try Data(assetID.utf8).write(to: fixture.assetFileURL(assetID))
            try Data("thumb-\(assetID)".utf8).write(to: fixture.thumbnailURL(assetID))
        }

        let pack = AssetPack(
            id: fixture.packID,
            displayName: "Removal Test Pack",
            source: "tests",
            importedAt: Date(timeIntervalSince1970: 10),
            assetCount: assetIDs.count
        )
        let assets = assetIDs.map { fixture.asset(id: $0) }
        try fixture.store.replacePack(pack, assets: assets)
        try writeManifest(pack: pack, assets: assets, paths: fixture.paths)
    }

    private func writeManifest(pack: AssetPack, assets: [DesignAsset], paths: LibraryPaths) throws {
        let packRoot = paths.packLibraryURL(pack.id)
        let manifest = PackManifest(
            schemaVersion: 1,
            packID: pack.id,
            displayName: pack.displayName,
            source: pack.source,
            importedAt: pack.importedAt,
            importerVersion: "test",
            assetCount: assets.count,
            rules: [:],
            assets: assets.map { asset in
                ManifestAsset(
                    id: asset.id,
                    displayName: asset.displayName,
                    originalFiles: asset.variants.map(\.originalFileName),
                    variants: Dictionary(uniqueKeysWithValues: asset.variants.map {
                        ($0.role.rawValue, $0.fileURL.relativePath(from: packRoot))
                    }),
                    tags: [:]
                )
            }
        )

        let data = try DateCoding.encoder.encode(manifest)
        try data.write(to: paths.packManifestURL(pack.id), options: [.atomic])
    }
}

private struct RemovalFixture {
    let root: URL
    let paths: LibraryPaths
    let store: AssetStore
    let packID = "pack-a"

    var assetDirectory: URL {
        paths.packLibraryURL(packID).appendingPathComponent("assets", isDirectory: true)
    }

    func assetFileURL(_ assetID: String) -> URL {
        assetDirectory.appendingPathComponent("\(assetID).png")
    }

    func thumbnailURL(_ assetID: String) -> URL {
        paths.thumbnails.appendingPathComponent("\(assetID).png")
    }

    func asset(id: String) -> DesignAsset {
        let variantID = "\(id)-original"
        return DesignAsset(
            id: id,
            packID: packID,
            displayName: id.capitalized,
            normalizedName: "\(id).png",
            primaryVariantID: variantID,
            kind: "texture",
            createdAt: Date(timeIntervalSince1970: 20),
            variants: [
                AssetVariant(
                    id: variantID,
                    assetID: id,
                    role: .original,
                    fileURL: assetFileURL(id),
                    originalFileName: "\(id).png",
                    fileExtension: "png",
                    width: 100,
                    height: 100,
                    hasAlpha: true,
                    byteCount: 10
                )
            ],
            tags: [
                AssetTag(
                    namespace: "kind",
                    value: "texture",
                    source: "auto",
                    confidence: 1,
                    protected: false
                )
            ],
            thumbnailURL: thumbnailURL(id)
        )
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }
}
