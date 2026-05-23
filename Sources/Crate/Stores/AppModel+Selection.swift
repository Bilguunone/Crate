//
//  AppModel+Selection.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import AppKit
import Foundation

extension AppModel {
    func select(_ asset: DesignAsset) {
        selectOnly(asset)
    }

    func handleGridSelection(of asset: DesignAsset, in visibleAssets: [DesignAsset]) {
        let modifiers = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if modifiers.contains(.shift) {
            selectRange(to: asset, in: visibleAssets, extending: modifiers.contains(.command))
        } else if modifiers.contains(.command) {
            toggleSelection(asset)
        } else {
            selectOnly(asset)
        }
    }

    func selectOnly(_ asset: DesignAsset) {
        selectedAssetIDs = [asset.id]
        selectedAssetID = asset.id
        selectionAnchorAssetID = asset.id
    }

    func toggleSelection(_ asset: DesignAsset) {
        if selectedAssetIDs.contains(asset.id) {
            selectedAssetIDs.remove(asset.id)
            if selectedAssetID == asset.id {
                selectedAssetID = selectedAssets.first?.id ?? filteredAssets.first?.id
            }
        } else {
            selectedAssetIDs.insert(asset.id)
            selectedAssetID = asset.id
            selectionAnchorAssetID = asset.id
        }

        if selectedAssetIDs.isEmpty {
            selectedAssetID = nil
            selectionAnchorAssetID = nil
        }
    }

    func selectRange(to asset: DesignAsset, in visibleAssets: [DesignAsset], extending: Bool = false) {
        guard let targetIndex = visibleAssets.firstIndex(where: { $0.id == asset.id }) else {
            selectOnly(asset)
            return
        }

        let anchorID = selectionAnchorAssetID ?? selectedAssetID ?? visibleAssets.first?.id
        guard let anchorID,
              let anchorIndex = visibleAssets.firstIndex(where: { $0.id == anchorID })
        else {
            selectOnly(asset)
            return
        }

        let bounds = min(anchorIndex, targetIndex)...max(anchorIndex, targetIndex)
        let rangeIDs = Set(visibleAssets[bounds].map(\.id))
        selectedAssetIDs = extending ? selectedAssetIDs.union(rangeIDs) : rangeIDs
        selectedAssetID = asset.id
    }

    func selectAllFilteredAssets() {
        selectedAssetIDs = Set(filteredAssets.map(\.id))
        selectedAssetID = filteredAssets.first?.id
        selectionAnchorAssetID = selectedAssetID
    }

    func replaceSelection(with assetIDs: Set<String>, focusAssetID: String? = nil) {
        let visibleIDs = Set(filteredAssets.map(\.id))
        let sanitizedAssetIDs = assetIDs.intersection(visibleIDs)
        selectedAssetIDs = sanitizedAssetIDs

        guard !sanitizedAssetIDs.isEmpty else {
            selectedAssetID = nil
            selectionAnchorAssetID = nil
            return
        }

        let firstVisibleSelectedID = filteredAssets.first { asset in
            sanitizedAssetIDs.contains(asset.id)
        }?.id
        selectedAssetID = focusAssetID.flatMap { sanitizedAssetIDs.contains($0) ? $0 : nil } ?? firstVisibleSelectedID
        selectionAnchorAssetID = selectedAssetID
    }

    func clearSelection() {
        selectedAssetIDs = []
        selectedAssetID = nil
        selectionAnchorAssetID = nil
    }

    func reconcileSelectionWithVisibleAssets() {
        let visibleIDs = Set(filteredAssets.map(\.id))
        selectedAssetIDs = selectedAssetIDs.intersection(visibleIDs)

        if let selectedAssetID, visibleIDs.contains(selectedAssetID) {
            if selectedAssetIDs.isEmpty {
                selectedAssetIDs = [selectedAssetID]
            }
            if selectionAnchorAssetID == nil {
                selectionAnchorAssetID = selectedAssetID
            }
            return
        }

        if let firstSelectedID = selectedAssetIDs.first(where: { visibleIDs.contains($0) }) {
            selectedAssetID = firstSelectedID
            selectionAnchorAssetID = firstSelectedID
            return
        }

        if let firstAsset = filteredAssets.first {
            selectOnly(firstAsset)
        } else {
            clearSelection()
        }
    }
}
