//
//  AppModel+Browsing.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import Foundation

extension AppModel {
    func focusSearch() {
        searchFocusRequest += 1
    }

    func applyFilter(_ filter: SidebarFilter) {
        if filter == .shuffle {
            shuffleCurrentResults()
            return
        }
        if case .smart(.similarToSelected) = filter {
            smartSimilarAnchorID = selectedAssetID ?? selectedAsset?.id
        }
        shuffledAssetIDs = []
        selectedFilter = filter
        refreshFilteredAssets(selectFirst: true)
    }

    func setRefinedKind(_ kind: String?) {
        refinedKind = kind
        refreshFilteredAssets()
    }

    func setRefinedMaterial(_ material: String?) {
        refinedMaterial = material
        refreshFilteredAssets()
    }

    func setRefinedUse(_ use: String?) {
        refinedUse = use
        refreshFilteredAssets()
    }

    func setRefinedAlpha(_ alpha: AssetAlphaFilter) {
        refinedAlpha = alpha
        refreshFilteredAssets()
    }

    func setSortMode(_ mode: AssetSortMode) {
        sortMode = mode
        refreshFilteredAssets()
    }

    func clearRefinements() {
        refinedKind = nil
        refinedMaterial = nil
        refinedUse = nil
        refinedAlpha = .any
        sortMode = .name
        refreshFilteredAssets()
    }

    func selectVariant(_ variant: AssetVariant, for asset: DesignAsset) {
        selectedVariantByAsset[asset.id] = variant.id
    }

    func shuffleCurrentResults() {
        let source = selectedFilter == .shuffle ? assets : filteredAssets
        shuffledAssetIDs = Array(source.shuffled().prefix(12)).map(\.id)
        selectedFilter = .shuffle
        refreshFilteredAssets(selectFirst: true)
    }

    func similarAssets(to asset: DesignAsset) -> [DesignAsset] {
        if asset.id == selectedAssetID {
            return selectedSimilarAssets
        }
        return SimilarityService.similarAssets(to: asset, in: assets)
    }

    func duplicateClusters(for asset: DesignAsset) -> [DuplicateCluster] {
        duplicateClustersByAssetID[asset.id] ?? []
    }

    func refreshFilteredAssets(selectFirst: Bool = false) {
        filteredAssetComputationTask?.cancel()
        filteredAssetComputationGeneration += 1

        let generation = filteredAssetComputationGeneration
        let snapshot = assetFilterSnapshot()
        let detail = "assets=\(snapshot.assets.count) search=\(snapshot.searchText.isEmpty ? "empty" : "active") filter=\(snapshot.selectedFilter.id)"

        if snapshot.assets.count < 900 {
            let result = CrateTelemetry.measure("filter.sync", details: detail) {
                AssetFilteringService.filteredAssets(for: snapshot)
            }
            applyFilteredAssets(result, selectFirst: selectFirst)
            return
        }

        filteredAssetComputationTask = Task { [weak self] in
            let result = await CrateTelemetry.measureAsync("filter.async", details: detail) {
                await Task.detached(priority: .userInitiated) {
                    AssetFilteringService.filteredAssets(for: snapshot)
                }.value
            }

            guard !Task.isCancelled else { return }
            guard let self, self.filteredAssetComputationGeneration == generation else { return }
            applyFilteredAssets(result, selectFirst: selectFirst)
        }
    }

    func applyFilteredAssets(_ result: [DesignAsset], selectFirst: Bool) {
        filteredAssets = result
        if selectFirst {
            if let first = result.first {
                selectOnly(first)
            } else {
                clearSelection()
            }
            return
        }

        reconcileSelectionWithFilteredAssets()
    }

    func rebuildLibraryCaches() {
        CrateTelemetry.measure("library.cache.rebuild", details: "assets=\(assets.count) packs=\(packs.count)") {
            rebuildLibraryCachesImpl()
        }
    }

    private func rebuildLibraryCachesImpl() {
        assetsByIDCache = Dictionary(uniqueKeysWithValues: assets.map { ($0.id, $0) })
        packNameByIDCache = Dictionary(uniqueKeysWithValues: packs.map { ($0.id, $0.displayName) })
        packImportedAtByIDCache = Dictionary(uniqueKeysWithValues: packs.map { ($0.id, $0.importedAt) })

        var tagsByAsset: [String: Set<String>] = [:]
        var tagValuesByNamespace: [String: Set<String>] = [:]
        var searchableText: [String: String] = [:]
        var searchDocuments: [String: AssetSearchDocument] = [:]
        var userTagsByAsset: [String: [AssetTag]] = [:]
        var userTagCounts: [String: (namespace: String, value: String, count: Int)] = [:]
        var userTagAssets: [String: Set<String>] = [:]
        var qualityAssets: [String: Set<String>] = [:]

        for asset in assets {
            var tagKeys = Set<String>()
            var searchableParts = [
                asset.displayName,
                asset.normalizedName,
                asset.kind,
                packNameByIDCache[asset.packID] ?? asset.packID
            ]

            for tag in asset.tags {
                tagKeys.insert(tagKey(tag.namespace, tag.value))
                tagValuesByNamespace[tag.namespace, default: []].insert(tag.value)
                searchableParts.append(tag.namespace)
                searchableParts.append(tag.value)

                if tag.source == "user", tag.protected {
                    let key = tagKey(tag.namespace, tag.value)
                    userTagsByAsset[asset.id, default: []].append(tag)
                    userTagAssets[key, default: []].insert(asset.id)
                    var count = userTagCounts[key] ?? (tag.namespace, tag.value, 0)
                    count.count += 1
                    userTagCounts[key] = count
                } else if tag.namespace == "quality" {
                    qualityAssets[tag.value, default: []].insert(asset.id)
                }
            }

            tagsByAsset[asset.id] = tagKeys
            searchableText[asset.id] = searchableParts
                .joined(separator: " ")
                .lowercased()
            searchDocuments[asset.id] = AssetSearchDocument(
                asset: asset,
                packName: packNameByIDCache[asset.packID] ?? asset.packID
            )
        }

        assetTagsByID = tagsByAsset
        self.tagValuesByNamespace = tagValuesByNamespace
        searchableTextByAssetID = searchableText
        searchDocumentsByAssetID = searchDocuments
        userTagsByAssetID = userTagsByAsset.mapValues {
            $0.sorted { lhs, rhs in
                if lhs.namespace == rhs.namespace { return lhs.value < rhs.value }
                return lhs.namespace < rhs.namespace
            }
        }
        userTagAssetIDsByKey = userTagAssets
        qualityAssetIDsByValue = qualityAssets
        qualityFacetCounts = qualityAssets.mapValues { $0.count }
        userTagFacets = userTagCounts.values
            .map { UserTagFacet(namespace: $0.namespace, value: $0.value, count: $0.count) }
            .sorted {
                if $0.namespace == $1.namespace {
                    return $0.value.localizedStandardCompare($1.value) == .orderedAscending
                }
                return $0.namespace.localizedStandardCompare($1.namespace) == .orderedAscending
            }

        kindFacets = Array(Set(assets.map(\.kind)).union(tagValuesByNamespace["kind"] ?? [])).sorted()
        materialFacets = facetValues(namespace: "material")
        useFacets = facetValues(namespace: "use")
        colorFacets = facetValues(namespace: "color")
        brightnessFacets = orderedFacetValues(namespace: "brightness", order: ["dark", "medium", "bright"])
        contrastFacets = orderedFacetValues(namespace: "contrast", order: ["low", "medium", "high"])
        orientationFacets = orderedFacetValues(namespace: "orientation", order: ["square", "landscape", "portrait", "panoramic", "tall"])
        transparencyFacets = orderedFacetValues(namespace: "transparency", order: ["none", "light", "partial", "heavy", "full"])
        edgeDensityFacets = orderedFacetValues(namespace: "edge_density", order: ["soft", "moderate", "busy"])
        qualityFacets = QualityWarningCatalog.orderedValues(from: tagValuesByNamespace["quality"] ?? [])
        hasVisualFacets = !brightnessFacets.isEmpty
            || !contrastFacets.isEmpty
            || !orientationFacets.isEmpty
            || !transparencyFacets.isEmpty
            || !edgeDensityFacets.isEmpty

        rebuildDuplicateClusterCache()
        rebuildSmartAssetIDCaches()
        rebuildSidebarCaches()
    }

    func rebuildSmartAssetIDCaches() {
        cartAssetIDs = Set(cartItems.map(\.assetID))
        favoriteAssetCount = favoriteAssetIDs.count
        hasAlphaAssetIDs = Set(assets.filter(\.hasAlpha).map(\.id))
        hasAlphaAssetCount = hasAlphaAssetIDs.count
        unusedGemAssetIDs = Set(assets.lazy.filter { asset in
            !self.usedAssetIDs.contains(asset.id) && !self.cartAssetIDs.contains(asset.id)
        }.map(\.id))
        plasticOverlayAssetIDs = Set(assets.lazy.filter { asset in
            asset.kind == "overlay" && self.asset(asset, hasTag: "material", value: "plastic")
        }.map(\.id))
        paperTextureAssetIDs = Set(assets.lazy.filter { asset in
            asset.kind == "texture" && self.asset(asset, hasTag: "material", value: "paper")
        }.map(\.id))

        if let newestPackImportDate = packs.map(\.importedAt).max() {
            let latestBatchWindow: TimeInterval = 10 * 60
            let latestPackIDs = Set(packs.lazy.filter {
                newestPackImportDate.timeIntervalSince($0.importedAt) <= latestBatchWindow
            }.map(\.id))
            recentlyImportedAssetIDs = Set(assets.lazy.filter { latestPackIDs.contains($0.packID) }.map(\.id))
        } else {
            recentlyImportedAssetIDs = []
        }
    }

    func rebuildSidebarCaches() {
        smartCollections = SmartCollectionKind.allCases.map { kind in
            SmartCollectionDefinition(
                kind: kind,
                count: smartCount(for: kind),
                detail: smartDetail(for: kind)
            )
        }
    }

    func rebuildDuplicateClusterCache() {
        var clustersByAssetID: [String: [DuplicateCluster]] = [:]
        let clusters = duplicateReport.exactFileGroups
            + duplicateReport.sameImageGroups
            + duplicateReport.nearDuplicateGroups

        for cluster in clusters {
            for assetID in cluster.assetIDs {
                clustersByAssetID[assetID, default: []].append(cluster)
            }
        }

        duplicateClustersByAssetID = clustersByAssetID
        duplicateCandidateAssetIDs = Set(clusters.flatMap(\.assetIDs))
        duplicateCandidateAssetCount = duplicateCandidateAssetIDs.count
        hasQualityWarnings = !qualityFacets.isEmpty || !duplicateCandidateAssetIDs.isEmpty
    }

    func refreshSelectedAssetDerivedData() {
        selectedDuplicateClusters = selectedAssetID.flatMap { duplicateClustersByAssetID[$0] } ?? []
        scheduleSelectedSimilarityRefresh()
        rebuildSidebarCaches()
    }

    func scheduleFilteredAssetRefresh() {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 140_000_000)
            guard !Task.isCancelled else { return }
            self?.refreshFilteredAssets()
        }
    }

    func refreshAfterCartChange() {
        rebuildSmartAssetIDCaches()
        rebuildSidebarCaches()
        if case .smart(.cart) = selectedFilter {
            refreshFilteredAssets()
        } else if case .smart(.unusedGems) = selectedFilter {
            refreshFilteredAssets()
        }
    }

    func reloadPreservingSelection() throws {
        let selectedID = selectedAssetID
        try reload()
        if let selectedID, assetsByID[selectedID] != nil {
            selectedAssetID = selectedID
        }
        refreshFilteredAssets()
        refreshSelectedAssetDerivedData()
    }

    func reconcileSelectionWithFilteredAssets() {
        guard let selectedAssetID,
              filteredAssets.contains(where: { $0.id == selectedAssetID })
        else {
            reconcileSelectionWithVisibleAssets()
            return
        }
        reconcileSelectionWithVisibleAssets()
    }

}

private extension AppModel {
    func assetFilterSnapshot() -> AssetFilterSnapshot {
        AssetFilterSnapshot(
            assets: assets,
            selectedFilter: selectedFilter,
            collections: collections,
            shuffledAssetIDs: shuffledAssetIDs,
            refinedKind: refinedKind,
            refinedMaterial: refinedMaterial,
            refinedUse: refinedUse,
            refinedAlpha: refinedAlpha,
            sortMode: sortMode,
            searchText: searchText,
            assetsByID: assetsByIDCache,
            assetTagsByID: assetTagsByID,
            userTagAssetIDsByKey: userTagAssetIDsByKey,
            recentlyImportedAssetIDs: recentlyImportedAssetIDs,
            favoriteAssetIDs: favoriteAssetIDs,
            hasAlphaAssetIDs: hasAlphaAssetIDs,
            unusedGemAssetIDs: unusedGemAssetIDs,
            plasticOverlayAssetIDs: plasticOverlayAssetIDs,
            paperTextureAssetIDs: paperTextureAssetIDs,
            cartAssetIDs: cartAssetIDs,
            selectedSimilarAssetIDSet: selectedSimilarAssetIDSet,
            duplicateCandidateAssetIDs: duplicateCandidateAssetIDs,
            packNameByID: packNameByIDCache,
            searchDocumentsByAssetID: searchDocumentsByAssetID
        )
    }
}
