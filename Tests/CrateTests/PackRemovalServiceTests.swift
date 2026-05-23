//
//  PackRemovalServiceTests.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import XCTest
@testable import Crate

final class PackRemovalServiceTests: XCTestCase {
    func testPackRemovalCanKeepVaultFolder() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        try seedPack(fixture)

        let result = try PackRemovalService.remove(
            packID: fixture.packID,
            store: fixture.store,
            paths: fixture.paths,
            deleteFromVault: false
        )

        XCTAssertEqual(result.removedAssetCount, 1)
        XCTAssertEqual(result.removedThumbnailCount, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.assetFileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.paths.packLibraryURL(fixture.packID).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.paths.packManifestURL(fixture.packID).path))
        XCTAssertEqual(try fixture.store.fetchAssets(), [])
        XCTAssertEqual(try fixture.store.fetchPacks(), [])
    }

    private func makeFixture() throws -> PackRemovalFixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CratePackRemovalTests-\(UUID().uuidString)", isDirectory: true)
        let paths = try LibraryManager.prepareLibrary(at: root, save: false)
        let store = try AssetStore(databaseURL: paths.databaseURL)
        return PackRemovalFixture(root: root, paths: paths, store: store)
    }

    private func seedPack(_ fixture: PackRemovalFixture) throws {
        try FileManager.default.createDirectory(
            at: fixture.assetFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("asset".utf8).write(to: fixture.assetFileURL)
        try Data("thumb".utf8).write(to: fixture.thumbnailURL)

        let pack = AssetPack(
            id: fixture.packID,
            displayName: "Vault Test Pack",
            source: "tests",
            importedAt: Date(timeIntervalSince1970: 10),
            assetCount: 1
        )
        try fixture.store.replacePack(pack, assets: [fixture.asset])

        let manifest = PackManifest(
            schemaVersion: 1,
            packID: pack.id,
            displayName: pack.displayName,
            source: pack.source,
            importedAt: pack.importedAt,
            importerVersion: "test",
            assetCount: 1,
            rules: [:],
            assets: [
                ManifestAsset(
                    id: fixture.asset.id,
                    displayName: fixture.asset.displayName,
                    originalFiles: [fixture.asset.primaryVariant?.originalFileName ?? ""],
                    variants: ["original": fixture.assetFileURL.relativePath(from: fixture.paths.packLibraryURL(fixture.packID))],
                    tags: [:]
                )
            ]
        )
        let data = try DateCoding.encoder.encode(manifest)
        try data.write(to: fixture.paths.packManifestURL(fixture.packID), options: [.atomic])
    }
}

private struct PackRemovalFixture {
    let root: URL
    let paths: LibraryPaths
    let store: AssetStore
    let packID = "pack-a"

    var assetFileURL: URL {
        paths.packLibraryURL(packID)
            .appendingPathComponent("assets", isDirectory: true)
            .appendingPathComponent("asset-a.png")
    }

    var thumbnailURL: URL {
        paths.thumbnails.appendingPathComponent("asset-a.png")
    }

    var asset: DesignAsset {
        DesignAsset(
            id: "asset-a",
            packID: packID,
            displayName: "Asset A",
            normalizedName: "asset-a.png",
            primaryVariantID: "asset-a-original",
            kind: "texture",
            createdAt: Date(timeIntervalSince1970: 20),
            variants: [
                AssetVariant(
                    id: "asset-a-original",
                    assetID: "asset-a",
                    role: .original,
                    fileURL: assetFileURL,
                    originalFileName: "asset-a.png",
                    fileExtension: "png",
                    width: 100,
                    height: 100,
                    hasAlpha: true,
                    byteCount: 10
                )
            ],
            tags: [],
            thumbnailURL: thumbnailURL
        )
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }
}
