//
//  AppModelRecentlyImportedTests.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import XCTest
@testable import Crate

@MainActor
final class AppModelRecentlyImportedTests: XCTestCase {
    func testRecentlyImportedUsesLatestImportBatchNotWholeWeek() {
        let model = AppModel()
        let oldDate = Date(timeIntervalSince1970: 1_000)
        let latestDate = Date(timeIntervalSince1970: 10_000)
        let sameBatchDate = latestDate.addingTimeInterval(-60)

        model.packs = [
            pack(id: "old-pack", importedAt: oldDate),
            pack(id: "latest-pack", importedAt: latestDate),
            pack(id: "same-batch-pack", importedAt: sameBatchDate)
        ]
        model.assets = [
            asset(id: "old-asset", packID: "old-pack"),
            asset(id: "latest-asset", packID: "latest-pack"),
            asset(id: "same-batch-asset", packID: "same-batch-pack")
        ]

        model.rebuildLibraryCaches()

        XCTAssertEqual(model.recentlyImportedAssetIDs, ["latest-asset", "same-batch-asset"])
        XCTAssertEqual(model.smartCount(for: .recentlyImported), 2)
    }

    private func pack(id: String, importedAt: Date) -> AssetPack {
        AssetPack(
            id: id,
            displayName: id,
            source: "test",
            importedAt: importedAt,
            assetCount: 1
        )
    }

    private func asset(id: String, packID: String) -> DesignAsset {
        DesignAsset(
            id: id,
            packID: packID,
            displayName: id,
            normalizedName: id,
            primaryVariantID: "\(id)-original",
            kind: "texture",
            createdAt: Date(timeIntervalSince1970: 1),
            variants: [],
            tags: [],
            thumbnailURL: nil
        )
    }
}
