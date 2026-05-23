//
//  AppModel.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-22.
//

import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    var libraryRoot: URL?
    var isLibraryOpen = false
    var packs: [AssetPack] = []
    var assets: [DesignAsset] = []
    var collections: [AssetCollection] = []
    var cartItems: [CartItem] = []
    var usedAssetIDs: Set<String> = []
    var favoriteAssetIDs: Set<String> = []
    var selectedFilter: SidebarFilter = .all
    var selectedAssetIDs: Set<String> = []
    var refinedKind: String?
    var refinedMaterial: String?
    var refinedUse: String?
    var refinedAlpha: AssetAlphaFilter = .any
    var sortMode: AssetSortMode = .name
    var selectedAssetID: String? {
        didSet {
            guard selectedAssetID != oldValue else { return }
            refreshSelectedAssetDerivedData()
        }
    }
    var smartSimilarAnchorID: String?
    var searchText = "" {
        didSet {
            guard searchText != oldValue else { return }
            scheduleFilteredAssetRefresh()
        }
    }
    var searchFocusRequest = 0
    var statusMessage = "Choose a library to start."
    var isImporting = false
    var isScanningDuplicates = false
    var isAnalyzingVisualTags = false
    var lastExportURL: URL?
    var selectedVariantByAsset: [String: String] = [:]
    var shuffledAssetIDs: [String] = []
    var importReviewDraft: ImportReviewDraft?
    var pendingPackRemoval: AssetPack?
    var pendingAssetRemovalIDs: Set<String> = []
    var pendingLibraryMigration: LibraryMigrationPlan?
    var missingLibraryRoot: URL?
    var libraryValidationReport: LibraryValidationReport?
    var duplicateReport: DuplicateReport = .empty
    var isMigratingLibrary = false
    var isValidatingLibrary = false
    var filteredAssets: [DesignAsset] = []
    var hasAlphaAssetCount = 0
    var kindFacets: [String] = []
    var materialFacets: [String] = []
    var useFacets: [String] = []
    var colorFacets: [String] = []
    var brightnessFacets: [String] = []
    var contrastFacets: [String] = []
    var orientationFacets: [String] = []
    var transparencyFacets: [String] = []
    var edgeDensityFacets: [String] = []
    var hasVisualFacets = false
    var smartCollections: [SmartCollectionDefinition] = []
    var favoriteAssetCount = 0
    var userTagFacets: [UserTagFacet] = []
    var selectedSimilarAssets: [DesignAsset] = []
    var selectedDuplicateClusters: [DuplicateCluster] = []
    var isFindingSimilarAssets = false
    var pixelmatorOpenDocumentCount = 0
    var pixelmatorFrontDocumentPath: String?
    var pixelmatorFrontDocumentName: String?
    var isSendingToPixelmator = false

    @ObservationIgnored var importReviewRefreshTask: Task<Void, Never>?
    @ObservationIgnored var duplicateScanTask: Task<Void, Never>?
    @ObservationIgnored var searchDebounceTask: Task<Void, Never>?
    @ObservationIgnored var filteredAssetComputationTask: Task<Void, Never>?
    @ObservationIgnored var filteredAssetComputationGeneration = 0
    @ObservationIgnored var similarityTask: Task<Void, Never>?
    @ObservationIgnored var libraryChangePollingTask: Task<Void, Never>?
    @ObservationIgnored var pixelmatorProjectPollingTask: Task<Void, Never>?
    @ObservationIgnored var libraryDatabaseSignature: LibraryDatabaseSignature?
    @ObservationIgnored var selectionAnchorAssetID: String?
    @ObservationIgnored var assetsByIDCache: [String: DesignAsset] = [:]
    @ObservationIgnored var packNameByIDCache: [String: String] = [:]
    @ObservationIgnored var packImportedAtByIDCache: [String: Date] = [:]
    @ObservationIgnored var assetTagsByID: [String: Set<String>] = [:]
    @ObservationIgnored var searchableTextByAssetID: [String: String] = [:]
    @ObservationIgnored var searchDocumentsByAssetID: [String: AssetSearchDocument] = [:]
    @ObservationIgnored var tagValuesByNamespace: [String: Set<String>] = [:]
    @ObservationIgnored var userTagsByAssetID: [String: [AssetTag]] = [:]
    @ObservationIgnored var userTagAssetIDsByKey: [String: Set<String>] = [:]
    @ObservationIgnored var recentlyImportedAssetIDs: Set<String> = []
    @ObservationIgnored var hasAlphaAssetIDs: Set<String> = []
    @ObservationIgnored var unusedGemAssetIDs: Set<String> = []
    @ObservationIgnored var plasticOverlayAssetIDs: Set<String> = []
    @ObservationIgnored var paperTextureAssetIDs: Set<String> = []
    @ObservationIgnored var cartAssetIDs: Set<String> = []
    @ObservationIgnored var duplicateCandidateAssetIDs: Set<String> = []
    @ObservationIgnored var selectedSimilarAssetIDSet: Set<String> = []
    @ObservationIgnored var duplicateClustersByAssetID: [String: [DuplicateCluster]] = [:]
    @ObservationIgnored var paths: LibraryPaths?
    @ObservationIgnored var store: AssetStore?

    var hasLibrary: Bool {
        isLibraryOpen
    }

    var importPresets: [ImportPreset] {
        ImportPresetCatalog.resourceBoy
    }

    var assetsByID: [String: DesignAsset] {
        assetsByIDCache
    }

    var selectedAsset: DesignAsset? {
        if let selectedAssetID, let asset = assetsByID[selectedAssetID] {
            return asset
        }
        return filteredAssets.first
    }

    var selectedAssets: [DesignAsset] {
        let selectedIDs = selectedAssetIDs
        guard !selectedIDs.isEmpty else { return [] }
        let visible = filteredAssets.filter { selectedIDs.contains($0.id) }
        let visibleIDs = Set(visible.map(\.id))
        let hidden = selectedIDs
            .subtracting(visibleIDs)
            .compactMap { assetsByID[$0] }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        return visible + hidden
    }

    var selectedAssetCount: Int {
        selectedAssetIDs.count
    }

    var selectedAssetsAreAllFavorites: Bool {
        !selectedAssetIDs.isEmpty && selectedAssetIDs.allSatisfy { favoriteAssetIDs.contains($0) }
    }

    var selectedPack: AssetPack? {
        guard case .pack(let packID) = selectedFilter else { return nil }
        return packs.first { $0.id == packID }
    }

    var selectedVariant: AssetVariant? {
        guard let selectedAsset else { return nil }
        if let variantID = selectedVariantByAsset[selectedAsset.id] {
            return selectedAsset.variants.first(where: { $0.id == variantID }) ?? selectedAsset.primaryVariant
        }
        return selectedAsset.primaryVariant
    }

    var hasOpenPixelmatorProject: Bool {
        pixelmatorOpenDocumentCount > 0
    }

    var pixelmatorFrontDocumentURL: URL? {
        guard let pixelmatorFrontDocumentPath, !pixelmatorFrontDocumentPath.isEmpty else { return nil }
        return URL(fileURLWithPath: pixelmatorFrontDocumentPath)
    }

    var pixelmatorOpenProjectTitle: String {
        if let pixelmatorFrontDocumentName, !pixelmatorFrontDocumentName.isEmpty {
            return pixelmatorFrontDocumentName
        }
        return pixelmatorOpenDocumentCount == 1
            ? "Open Project"
            : "\(pixelmatorOpenDocumentCount) Open Projects"
    }

    var hasRefinements: Bool {
        refinedKind != nil
            || refinedMaterial != nil
            || refinedUse != nil
            || refinedAlpha != .any
            || sortMode != .name
    }

    var refinementSummary: String? {
        var parts: [String] = []
        if let refinedKind {
            parts.append(refinedKind.capitalized)
        }
        if let refinedMaterial {
            parts.append(refinedMaterial.capitalized)
        }
        if let refinedUse {
            parts.append(refinedUse.replacingOccurrences(of: "-", with: " ").capitalized)
        }
        if refinedAlpha != .any {
            parts.append(refinedAlpha.title)
        }
        if sortMode != .name {
            parts.append("Sort: \(sortMode.title)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var availableRefinementKinds: [String] {
        kindFacets
    }

    var availableRefinementMaterials: [String] {
        materialFacets
    }

    var availableRefinementUses: [String] {
        useFacets
    }

}
