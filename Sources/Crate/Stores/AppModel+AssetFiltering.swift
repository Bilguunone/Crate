//
//  AppModel+AssetFiltering.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import Foundation

extension AppModel {
    func primaryFilteredAssets() -> [DesignAsset] {
        var result = assets
        switch selectedFilter {
        case .all:
            break
        case .pack(let packID):
            result = result.filter { $0.packID == packID }
        case .kind(let kind):
            result = result.filter { $0.kind == kind || asset($0, hasTag: "kind", value: kind) }
        case .material(let material):
            result = result.filter { asset($0, hasTag: "material", value: material) }
        case .use(let use):
            result = result.filter { asset($0, hasTag: "use", value: use) }
        case .alpha:
            result = result.filter(\.hasAlpha)
        case .tag(let namespace, let value):
            result = result.filter { asset($0, hasTag: namespace, value: value) }
        case .userTag(let namespace, let value):
            let ids = userTagAssetIDsByKey[tagKey(namespace, value)] ?? []
            result = result.filter { ids.contains($0.id) }
        case .smart(let kind):
            result = smartAssets(for: kind, in: result)
        case .collection(let collectionID):
            let ids = Set(collections.first(where: { $0.id == collectionID })?.assetIDs ?? [])
            result = result.filter { ids.contains($0.id) }
        case .shuffle:
            if !shuffledAssetIDs.isEmpty {
                result = shuffledAssetIDs.compactMap { assetsByID[$0] }
            } else {
                result = Array(result.prefix(12))
            }
        }
        return result
    }

    func refinedAssets(_ source: [DesignAsset]) -> [DesignAsset] {
        var result = source
        if let refinedKind {
            result = result.filter { $0.kind == refinedKind || asset($0, hasTag: "kind", value: refinedKind) }
        }
        if let refinedMaterial {
            result = result.filter { asset($0, hasTag: "material", value: refinedMaterial) }
        }
        if let refinedUse {
            result = result.filter { asset($0, hasTag: "use", value: refinedUse) }
        }
        switch refinedAlpha {
        case .any:
            break
        case .hasAlpha:
            result = result.filter(\.hasAlpha)
        case .flat:
            result = result.filter { !$0.hasAlpha }
        }
        return result
    }

    func searchFilteredAssets(_ source: [DesignAsset]) -> [DesignAsset] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return source }
        return source.filter { asset in
            searchableTextByAssetID[asset.id]?.contains(trimmed) == true
        }
    }

    func sortedAssets(_ source: [DesignAsset]) -> [DesignAsset] {
        switch sortMode {
        case .name:
            return source.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        case .newest:
            return source.sorted {
                if $0.createdAt == $1.createdAt {
                    return $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
                }
                return $0.createdAt > $1.createdAt
            }
        case .pack:
            return source.sorted { lhs, rhs in
                let leftPack = packNameByIDCache[lhs.packID] ?? lhs.packID
                let rightPack = packNameByIDCache[rhs.packID] ?? rhs.packID
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

    func scheduleSelectedSimilarityRefresh() {
        similarityTask?.cancel()

        guard let asset = selectedAsset else {
            selectedSimilarAssets = []
            selectedSimilarAssetIDSet = []
            isFindingSimilarAssets = false
            return
        }

        selectedSimilarAssets = []
        selectedSimilarAssetIDSet = []
        isFindingSimilarAssets = true
        let snapshot = assets
        let selectedID = asset.id

        similarityTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 160_000_000)
            guard !Task.isCancelled else { return }

            let results = await CrateTelemetry.measureAsync(
                "similarity.selected",
                details: "assets=\(snapshot.count)"
            ) {
                await Task.detached(priority: .utility) {
                    SimilarityService.similarAssets(to: asset, in: snapshot, limit: 120)
                }.value
            }

            guard !Task.isCancelled else { return }
            guard let self, self.selectedAssetID == selectedID else { return }
            selectedSimilarAssets = Array(results.prefix(12))
            selectedSimilarAssetIDSet = Set(results.map(\.id))
            isFindingSimilarAssets = false
            rebuildSidebarCaches()

            if case .smart(.similarToSelected) = selectedFilter {
                refreshFilteredAssets()
            }
        }
    }

    func smartCount(for kind: SmartCollectionKind) -> Int {
        switch kind {
        case .recentlyImported:
            recentlyImportedAssetIDs.count
        case .favorites:
            favoriteAssetCount
        case .hasAlpha:
            hasAlphaAssetCount
        case .unusedGems:
            unusedGemAssetIDs.count
        case .plasticOverlays:
            plasticOverlayAssetIDs.count
        case .paperTextures:
            paperTextureAssetIDs.count
        case .cart:
            cartAssetIDs.count
        case .similarToSelected:
            selectedSimilarAssetIDSet.count
        case .duplicateWatch:
            duplicateCandidateAssetIDs.count
        }
    }

    func asset(_ asset: DesignAsset, hasTag namespace: String, value: String) -> Bool {
        assetTagsByID[asset.id]?.contains(tagKey(namespace, value)) == true
    }

    func qualityWarningCount(for value: String) -> Int {
        qualityFacetCounts[value] ?? 0
    }

    func tagKey(_ namespace: String, _ value: String) -> String {
        "\(namespace):\(value)"
    }

    func facetValues(namespace: String) -> [String] {
        Array(tagValuesByNamespace[namespace] ?? []).sorted()
    }

    func orderedFacetValues(namespace: String, order: [String]) -> [String] {
        let values = tagValuesByNamespace[namespace] ?? []
        return order.filter { values.contains($0) } + values.subtracting(order).sorted()
    }

    func smartAssets(for kind: SmartCollectionKind, in source: [DesignAsset]) -> [DesignAsset] {
        switch kind {
        case .recentlyImported:
            return source.filter { recentlyImportedAssetIDs.contains($0.id) }
        case .favorites:
            return source.filter { favoriteAssetIDs.contains($0.id) }
        case .hasAlpha:
            return source.filter { hasAlphaAssetIDs.contains($0.id) }
        case .unusedGems:
            return source.filter { unusedGemAssetIDs.contains($0.id) }
        case .plasticOverlays:
            return source.filter { plasticOverlayAssetIDs.contains($0.id) }
        case .paperTextures:
            return source.filter { paperTextureAssetIDs.contains($0.id) }
        case .cart:
            return source.filter { cartAssetIDs.contains($0.id) }
        case .similarToSelected:
            return source.filter { selectedSimilarAssetIDSet.contains($0.id) }
        case .duplicateWatch:
            return source.filter { duplicateCandidateAssetIDs.contains($0.id) }
        }
    }

    func smartDetail(for kind: SmartCollectionKind) -> String? {
        switch kind {
        case .recentlyImported:
            "latest batch"
        case .favorites:
            "hearted"
        case .hasAlpha:
            "transparent"
        case .unusedGems:
            "not used yet"
        case .plasticOverlays:
            "material:plastic"
        case .paperTextures:
            "material:paper"
        case .cart:
            "shared tray"
        case .similarToSelected:
            smartSimilarAnchorID.flatMap { assetsByID[$0]?.displayName } ?? "pick an asset"
        case .duplicateWatch:
            if isScanningDuplicates {
                "scanning..."
            } else if duplicateReport.scannedVariantCount == 0 {
                "not scanned"
            } else {
                "\(duplicateReport.totalIssueCount) groups"
            }
        }
    }
}
