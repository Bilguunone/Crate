//
//  AssetGridSelectionTests.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import XCTest
@testable import Crate

@MainActor
final class AssetGridSelectionTests: XCTestCase {
    func testMarqueeSelectionReturnsVisibleAssetsInGridOrder() {
        let assets = [
            asset(id: "asset-a"),
            asset(id: "asset-b"),
            asset(id: "asset-c")
        ]
        let frames: [String: CGRect] = [
            "asset-a": CGRect(x: 20, y: 20, width: 120, height: 120),
            "asset-b": CGRect(x: 156, y: 20, width: 120, height: 120),
            "asset-c": CGRect(x: 292, y: 20, width: 120, height: 120)
        ]

        let hits = AssetGridMarqueeSelectionResolver.hitAssetIDs(
            selectionRect: CGRect(x: 130, y: 10, width: 190, height: 150),
            visibleAssets: assets,
            itemFrames: frames
        )

        XCTAssertEqual(hits, ["asset-a", "asset-b", "asset-c"])
    }

    func testPointHitTestingUsesVisibleGridOrder() {
        let assets = [
            asset(id: "asset-a"),
            asset(id: "asset-b")
        ]
        let frames: [String: CGRect] = [
            "asset-a": CGRect(x: 20, y: 20, width: 120, height: 120),
            "asset-b": CGRect(x: 20, y: 20, width: 120, height: 120)
        ]

        let hit = AssetGridMarqueeSelectionResolver.hitAssetID(
            at: CGPoint(x: 40, y: 40),
            visibleAssets: assets,
            itemFrames: frames
        )
        let miss = AssetGridMarqueeSelectionResolver.hitAssetID(
            at: CGPoint(x: 200, y: 200),
            visibleAssets: assets,
            itemFrames: frames
        )

        XCTAssertEqual(hit, "asset-a")
        XCTAssertNil(miss)
    }

    func testReplaceSelectionDropsAssetsOutsideCurrentFilter() {
        let model = AppModel()
        model.assets = [
            asset(id: "asset-a"),
            asset(id: "asset-b"),
            asset(id: "asset-c")
        ]
        model.refreshFilteredAssets(selectFirst: false)

        model.replaceSelection(with: ["asset-a", "missing"], focusAssetID: "missing")

        XCTAssertEqual(model.selectedAssetIDs, ["asset-a"])
        XCTAssertEqual(model.selectedAssetID, "asset-a")
    }

    private func asset(id: String) -> DesignAsset {
        DesignAsset(
            id: id,
            packID: "pack-a",
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
