//
//  AssetFilteringService.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import Foundation

struct AssetFilterSnapshot: Sendable {
    let assets: [DesignAsset]
    let selectedFilter: SidebarFilter
    let collections: [AssetCollection]
    let shuffledAssetIDs: [String]
    let refinedKind: String?
    let refinedMaterial: String?
    let refinedUse: String?
    let refinedAlpha: AssetAlphaFilter
    let sortMode: AssetSortMode
    let searchText: String
    let assetsByID: [String: DesignAsset]
    let assetTagsByID: [String: Set<String>]
    let userTagAssetIDsByKey: [String: Set<String>]
    let recentlyImportedAssetIDs: Set<String>
    let favoriteAssetIDs: Set<String>
    let hasAlphaAssetIDs: Set<String>
    let unusedGemAssetIDs: Set<String>
    let plasticOverlayAssetIDs: Set<String>
    let paperTextureAssetIDs: Set<String>
    let cartAssetIDs: Set<String>
    let selectedSimilarAssetIDSet: Set<String>
    let duplicateCandidateAssetIDs: Set<String>
    let packNameByID: [String: String]
    let searchDocumentsByAssetID: [String: AssetSearchDocument]
}

enum AssetFilteringService {
    static func filteredAssets(for snapshot: AssetFilterSnapshot) -> [DesignAsset] {
        let primary = primaryFilteredAssets(for: snapshot)
        let refined = refinedAssets(primary, for: snapshot)
        let searched = searchFilteredAssets(refined, for: snapshot)
        return sortedAssets(searched, for: snapshot)
    }

    private static func primaryFilteredAssets(for snapshot: AssetFilterSnapshot) -> [DesignAsset] {
        var result = snapshot.assets
        switch snapshot.selectedFilter {
        case .all:
            break
        case .pack(let packID):
            result = result.filter { $0.packID == packID }
        case .kind(let kind):
            result = result.filter { $0.kind == kind || asset($0, hasTag: "kind", value: kind, in: snapshot) }
        case .material(let material):
            result = result.filter { asset($0, hasTag: "material", value: material, in: snapshot) }
        case .use(let use):
            result = result.filter { asset($0, hasTag: "use", value: use, in: snapshot) }
        case .alpha:
            result = result.filter(\.hasAlpha)
        case .tag(let namespace, let value):
            result = result.filter { asset($0, hasTag: namespace, value: value, in: snapshot) }
        case .userTag(let namespace, let value):
            let ids = snapshot.userTagAssetIDsByKey[tagKey(namespace, value)] ?? []
            result = result.filter { ids.contains($0.id) }
        case .smart(let kind):
            result = smartAssets(for: kind, in: result, snapshot: snapshot)
        case .collection(let collectionID):
            let ids = Set(snapshot.collections.first(where: { $0.id == collectionID })?.assetIDs ?? [])
            result = result.filter { ids.contains($0.id) }
        case .shuffle:
            if !snapshot.shuffledAssetIDs.isEmpty {
                result = snapshot.shuffledAssetIDs.compactMap { snapshot.assetsByID[$0] }
            } else {
                result = Array(result.prefix(12))
            }
        }
        return result
    }

    private static func refinedAssets(_ source: [DesignAsset], for snapshot: AssetFilterSnapshot) -> [DesignAsset] {
        var result = source
        if let refinedKind = snapshot.refinedKind {
            result = result.filter { $0.kind == refinedKind || asset($0, hasTag: "kind", value: refinedKind, in: snapshot) }
        }
        if let refinedMaterial = snapshot.refinedMaterial {
            result = result.filter { asset($0, hasTag: "material", value: refinedMaterial, in: snapshot) }
        }
        if let refinedUse = snapshot.refinedUse {
            result = result.filter { asset($0, hasTag: "use", value: refinedUse, in: snapshot) }
        }
        switch snapshot.refinedAlpha {
        case .any:
            break
        case .hasAlpha:
            result = result.filter(\.hasAlpha)
        case .flat:
            result = result.filter { !$0.hasAlpha }
        }
        return result
    }

    private static func searchFilteredAssets(_ source: [DesignAsset], for snapshot: AssetFilterSnapshot) -> [DesignAsset] {
        let query = AssetSearchQuery(snapshot.searchText)
        guard !query.terms.isEmpty else { return source }

        return source.enumerated().compactMap { index, asset -> (asset: DesignAsset, score: Double, index: Int)? in
            guard let document = snapshot.searchDocumentsByAssetID[asset.id] else { return nil }
            let score = document.score(for: query)
            guard score > 0 else { return nil }
            return (asset, score, index)
        }
        .sorted {
            if $0.score == $1.score {
                return $0.index < $1.index
            }
            return $0.score > $1.score
        }
        .map(\.asset)
    }

    private static func sortedAssets(_ source: [DesignAsset], for snapshot: AssetFilterSnapshot) -> [DesignAsset] {
        if snapshot.selectedFilter == .shuffle || snapshot.sortMode == .name {
            return source
        }

        switch snapshot.sortMode {
        case .name:
            return source
        case .newest:
            return source.sorted {
                if $0.createdAt == $1.createdAt {
                    return $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
                }
                return $0.createdAt > $1.createdAt
            }
        case .pack:
            return source.sorted { lhs, rhs in
                let leftPack = snapshot.packNameByID[lhs.packID] ?? lhs.packID
                let rightPack = snapshot.packNameByID[rhs.packID] ?? rhs.packID
                if leftPack == rightPack {
                    return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
                }
                return leftPack.localizedStandardCompare(rightPack) == .orderedAscending
            }
        case .kind:
            return source.sorted {
                if $0.kind == $1.kind {
                    return $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
                }
                return $0.kind.localizedStandardCompare($1.kind) == .orderedAscending
            }
        case .largest:
            return source.sorted { lhs, rhs in
                let leftArea = lhs.primaryVariant.map { $0.width * $0.height } ?? 0
                let rightArea = rhs.primaryVariant.map { $0.width * $0.height } ?? 0
                if leftArea == rightArea {
                    return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
                }
                return leftArea > rightArea
            }
        case .smallest:
            return source.sorted { lhs, rhs in
                let leftArea = lhs.primaryVariant.map { $0.width * $0.height } ?? 0
                let rightArea = rhs.primaryVariant.map { $0.width * $0.height } ?? 0
                if leftArea == rightArea {
                    return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
                }
                return leftArea < rightArea
            }
        }
    }

    private static func smartAssets(
        for kind: SmartCollectionKind,
        in source: [DesignAsset],
        snapshot: AssetFilterSnapshot
    ) -> [DesignAsset] {
        switch kind {
        case .recentlyImported:
            return source.filter { snapshot.recentlyImportedAssetIDs.contains($0.id) }
        case .favorites:
            return source.filter { snapshot.favoriteAssetIDs.contains($0.id) }
        case .hasAlpha:
            return source.filter { snapshot.hasAlphaAssetIDs.contains($0.id) }
        case .unusedGems:
            return source.filter { snapshot.unusedGemAssetIDs.contains($0.id) }
        case .plasticOverlays:
            return source.filter { snapshot.plasticOverlayAssetIDs.contains($0.id) }
        case .paperTextures:
            return source.filter { snapshot.paperTextureAssetIDs.contains($0.id) }
        case .cart:
            return source.filter { snapshot.cartAssetIDs.contains($0.id) }
        case .similarToSelected:
            return source.filter { snapshot.selectedSimilarAssetIDSet.contains($0.id) }
        case .duplicateWatch:
            return source.filter { snapshot.duplicateCandidateAssetIDs.contains($0.id) }
        }
    }

    private static func asset(
        _ asset: DesignAsset,
        hasTag namespace: String,
        value: String,
        in snapshot: AssetFilterSnapshot
    ) -> Bool {
        snapshot.assetTagsByID[asset.id]?.contains(tagKey(namespace, value)) == true
    }

    private static func tagKey(_ namespace: String, _ value: String) -> String {
        "\(namespace):\(value)"
    }
}
