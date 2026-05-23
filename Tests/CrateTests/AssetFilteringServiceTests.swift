//
//  AssetFilteringServiceTests.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import XCTest
@testable import Crate

final class AssetFilteringServiceTests: XCTestCase {
    func testNameSortKeepsExistingAssetOrder() {
        let first = asset(id: "b", displayName: "B")
        let second = asset(id: "a", displayName: "A")
        let result = AssetFilteringService.filteredAssets(
            for: snapshot(
                assets: [first, second],
                sortMode: .name
            )
        )

        XCTAssertEqual(result.map(\.id), ["b", "a"])
    }

    func testSearchUsesIndexedAssetFields() {
        let first = asset(id: "paper", displayName: "Burnt Paper")
        let second = asset(id: "plastic", displayName: "Plastic")
        let result = AssetFilteringService.filteredAssets(
            for: snapshot(
                assets: [first, second],
                searchText: "burnt"
            )
        )

        XCTAssertEqual(result.map(\.id), ["paper"])
    }

    func testSearchRanksExactNameBeforeTagMatches() {
        let exact = asset(id: "paper", displayName: "Burnt")
        let tagMatch = asset(
            id: "tagged",
            displayName: "Paper",
            tags: [AssetTag(namespace: "mood", value: "burnt", source: "auto", confidence: 1, protected: false)]
        )
        let result = AssetFilteringService.filteredAssets(
            for: snapshot(
                assets: [tagMatch, exact],
                searchText: "burnt"
            )
        )

        XCTAssertEqual(result.map(\.id), ["paper", "tagged"])
    }

    func testMaterialFilterUsesCachedTagKeys() {
        let paper = asset(id: "paper", displayName: "Paper")
        let plastic = asset(id: "plastic", displayName: "Plastic")
        let result = AssetFilteringService.filteredAssets(
            for: snapshot(
                assets: [paper, plastic],
                selectedFilter: .material("paper"),
                assetTagsByID: [
                    "paper": ["material:paper"],
                    "plastic": ["material:plastic"]
                ]
            )
        )

        XCTAssertEqual(result.map(\.id), ["paper"])
    }

    private func snapshot(
        assets: [DesignAsset],
        selectedFilter: SidebarFilter = .all,
        sortMode: AssetSortMode = .name,
        searchText: String = "",
        assetTagsByID: [String: Set<String>] = [:]
    ) -> AssetFilterSnapshot {
        let documents = Dictionary(uniqueKeysWithValues: assets.map { asset in
            (
                asset.id,
                AssetSearchDocument(asset: asset, packName: "Test Pack")
            )
        })

        return AssetFilterSnapshot(
            assets: assets,
            selectedFilter: selectedFilter,
            collections: [],
            shuffledAssetIDs: [],
            refinedKind: nil,
            refinedMaterial: nil,
            refinedUse: nil,
            refinedAlpha: .any,
            sortMode: sortMode,
            searchText: searchText,
            assetsByID: Dictionary(uniqueKeysWithValues: assets.map { ($0.id, $0) }),
            assetTagsByID: assetTagsByID,
            userTagAssetIDsByKey: [:],
            recentlyImportedAssetIDs: [],
            favoriteAssetIDs: [],
            hasAlphaAssetIDs: [],
            unusedGemAssetIDs: [],
            plasticOverlayAssetIDs: [],
            paperTextureAssetIDs: [],
            cartAssetIDs: [],
            selectedSimilarAssetIDSet: [],
            duplicateCandidateAssetIDs: [],
            packNameByID: [:],
            searchDocumentsByAssetID: documents
        )
    }

    private func asset(id: String, displayName: String, tags: [AssetTag] = []) -> DesignAsset {
        DesignAsset(
            id: id,
            packID: "pack-a",
            displayName: displayName,
            normalizedName: displayName.lowercased(),
            primaryVariantID: "\(id)-original",
            kind: "texture",
            createdAt: Date(timeIntervalSince1970: 1),
            variants: [],
            tags: tags,
            thumbnailURL: nil
        )
    }
}
