//
//  AppModel+Maintenance.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import Foundation

extension AppModel {
    func scanDuplicates() {
        runDuplicateScan(trigger: .manual)
    }

    func scanDuplicatesAfterImport(importMessage: String) {
        runDuplicateScan(trigger: .postImport(importMessage: importMessage))
    }

    func analyzeVisualTags() {
        guard !assets.isEmpty else {
            statusMessage = "No assets to analyze yet."
            return
        }

        let snapshot = assets
        isAnalyzingVisualTags = true

        Task { [weak self] in
            let report = await Task.detached(priority: .utility) {
                VisualAnalysisService.tagUpdates(for: snapshot)
            }.value

            guard let self else { return }
            guard let store = self.store else {
                isAnalyzingVisualTags = false
                return
            }
            do {
                try store.replaceComputedTags(report.updates)
                try reload()
                statusMessage = "Analyzed \(report.analyzedAssetCount) assets and wrote \(report.writtenTagCount) computed visual tags."
            } catch {
                statusMessage = error.localizedDescription
            }
            isAnalyzingVisualTags = false
        }
    }

    func requestRemovePack(_ pack: AssetPack) {
        pendingPackRemoval = pack
    }

    func cancelRemovePack() {
        pendingPackRemoval = nil
    }

    func requestRemoveAssets(_ assetIDs: Set<String>) {
        pendingAssetRemovalIDs = assetIDs.intersection(Set(assets.map(\.id)))
    }

    func requestRemoveSelectedAssets() {
        requestRemoveAssets(selectedAssetIDs)
    }

    func cancelRemoveAssets() {
        pendingAssetRemovalIDs = []
    }

    func confirmRemovePack(deleteFromVault: Bool = true) async {
        guard let pack = pendingPackRemoval, let paths, let store else { return }
        pendingPackRemoval = nil

        do {
            let result = try PackRemovalService.remove(
                packID: pack.id,
                store: store,
                paths: paths,
                deleteFromVault: deleteFromVault
            )
            try reload()
            if case .pack(pack.id) = selectedFilter {
                selectedFilter = .all
                refreshFilteredAssets(selectFirst: true)
            }
            statusMessage = deleteFromVault
                ? "Deleted \(result.displayName) from Crate and the library vault."
                : "Removed \(result.displayName) from Crate. The image files are still in the library vault."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func confirmRemoveAssets(deleteFromVault: Bool = true) async {
        let assetIDs = pendingAssetRemovalIDs
        guard !assetIDs.isEmpty, let paths, let store else { return }
        pendingAssetRemovalIDs = []

        do {
            let result = try AssetRemovalService.remove(
                assetIDs: assetIDs,
                store: store,
                paths: paths,
                deleteFromVault: deleteFromVault
            )
            try reload()
            selectedAssetIDs.subtract(assetIDs)
            reconcileSelectionWithVisibleAssets()
            if case .pack(let packID) = selectedFilter,
               !packs.contains(where: { $0.id == packID }) {
                selectedFilter = .all
                refreshFilteredAssets(selectFirst: true)
            }
            let noun = "asset\(result.removedAssetCount == 1 ? "" : "s")"
            statusMessage = deleteFromVault
                ? "Deleted \(result.removedAssetCount) \(noun) from Crate and the library vault."
                : "Removed \(result.removedAssetCount) \(noun) from Crate. The image files are still in the library vault."
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

private extension AppModel {
    func runDuplicateScan(trigger: DuplicateScanTrigger) {
        duplicateScanTask?.cancel()
        let snapshot = assets
        guard !snapshot.isEmpty else {
            duplicateReport = .empty
            isScanningDuplicates = false
            if trigger == .manual {
                statusMessage = "No assets to scan yet."
            }
            return
        }

        isScanningDuplicates = true
        if trigger == .manual {
            statusMessage = "Scanning \(snapshot.count) assets for duplicate weirdness..."
        }

        duplicateScanTask = Task { [weak self] in
            let report = await Task.detached(priority: .utility) {
                DuplicateDetectionService.scan(assets: snapshot)
            }.value
            guard !Task.isCancelled else { return }
            guard let self else { return }

            duplicateReport = report
            rebuildDuplicateClusterCache()
            rebuildSmartAssetIDCaches()
            rebuildSidebarCaches()
            selectedDuplicateClusters = selectedAssetID.flatMap { duplicateClustersByAssetID[$0] } ?? []
            if case .smart(.duplicateWatch) = selectedFilter {
                refreshFilteredAssets()
            }
            isScanningDuplicates = false
            updateStatusAfterDuplicateScan(report, trigger: trigger)
        }
    }

    func updateStatusAfterDuplicateScan(_ report: DuplicateReport, trigger: DuplicateScanTrigger) {
        switch trigger {
        case .manual:
            statusMessage = duplicateScanMessage(for: report)
        case .postImport(let importMessage):
            guard statusMessage == importMessage, report.totalIssueCount > 0 else { return }
            statusMessage = "\(importMessage) Duplicate Watch found \(duplicateIssueSummary(for: report))."
        }
    }

    func duplicateScanMessage(for report: DuplicateReport) -> String {
        guard report.totalFindingCount > 0 else {
            return "Duplicate scan complete. No duplicates found. Suspiciously civilized."
        }

        var parts: [String] = []
        if report.exactFileGroups.count > 0 {
            parts.append("\(report.exactFileGroups.count) exact")
        }
        if report.sameImageGroups.count > 0 {
            parts.append("\(report.sameImageGroups.count) same-image")
        }
        if report.nearDuplicateGroups.count > 0 {
            parts.append("\(report.nearDuplicateGroups.count) near")
        }
        if report.jpgPngVariantGroups.count > 0 {
            parts.append("\(report.jpgPngVariantGroups.count) JPG/PNG variant")
        }

        return "Duplicate scan complete: \(parts.joined(separator: ", ")) groups."
    }

    func duplicateIssueSummary(for report: DuplicateReport) -> String {
        var parts: [String] = []
        if report.exactFileGroups.count > 0 {
            parts.append("\(report.exactFileGroups.count) exact")
        }
        if report.sameImageGroups.count > 0 {
            parts.append("\(report.sameImageGroups.count) same-image")
        }
        if report.nearDuplicateGroups.count > 0 {
            parts.append("\(report.nearDuplicateGroups.count) near")
        }
        return parts.joined(separator: ", ") + " duplicate groups"
    }
}

private enum DuplicateScanTrigger: Equatable {
    case manual
    case postImport(importMessage: String)
}
