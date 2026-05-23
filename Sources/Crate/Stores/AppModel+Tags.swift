//
//  AppModel+Tags.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import Foundation

extension AppModel {
    func isFavorite(_ asset: DesignAsset) -> Bool {
        favoriteAssetIDs.contains(asset.id)
    }

    func toggleFavorite(_ asset: DesignAsset) {
        setFavorite(asset, isFavorite: !isFavorite(asset))
    }

    func setFavorite(_ asset: DesignAsset, isFavorite: Bool) {
        guard let store else { return }
        do {
            try store.setFavorite(assetID: asset.id, isFavorite: isFavorite)
            if isFavorite {
                favoriteAssetIDs.insert(asset.id)
                statusMessage = "Favorited \(asset.displayName)."
            } else {
                favoriteAssetIDs.remove(asset.id)
                statusMessage = "Removed favorite: \(asset.displayName)."
            }
            rebuildSmartAssetIDCaches()
            rebuildSidebarCaches()
            if case .smart(.favorites) = selectedFilter {
                refreshFilteredAssets()
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func setSelectedFavorite(_ isFavorite: Bool) {
        let ids = selectedAssetIDs
        guard !ids.isEmpty, let store else { return }

        do {
            for id in ids {
                try store.setFavorite(assetID: id, isFavorite: isFavorite)
            }
            if isFavorite {
                favoriteAssetIDs.formUnion(ids)
            } else {
                favoriteAssetIDs.subtract(ids)
            }
            rebuildSmartAssetIDCaches()
            rebuildSidebarCaches()
            if case .smart(.favorites) = selectedFilter {
                refreshFilteredAssets()
            }
            statusMessage = isFavorite
                ? "Favorited \(ids.count) selected asset\(ids.count == 1 ? "" : "s")."
                : "Removed \(ids.count) selected favorite\(ids.count == 1 ? "" : "s")."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func userTags(for asset: DesignAsset) -> [AssetTag] {
        userTagsByAssetID[asset.id] ?? []
    }

    func addUserTag(to asset: DesignAsset, rawValue: String) {
        guard let store else { return }
        guard let tag = UserTagParser.normalize(rawValue) else {
            statusMessage = "Type a tag first."
            return
        }

        do {
            try store.saveUserTag(assetID: asset.id, namespace: tag.namespace, value: tag.value)
            try reloadPreservingSelection()
            statusMessage = "Tagged \(asset.displayName) with \(tag.namespace):\(tag.value)."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func addUserTagToSelection(rawValue: String) {
        let ids = selectedAssetIDs
        guard !ids.isEmpty, let store else { return }
        guard let tag = UserTagParser.normalize(rawValue) else {
            statusMessage = "Type a tag first."
            return
        }

        do {
            for id in ids {
                try store.saveUserTag(assetID: id, namespace: tag.namespace, value: tag.value)
            }
            try reloadPreservingSelection()
            selectedAssetIDs = ids.intersection(Set(assets.map(\.id)))
            selectedAssetID = selectedAssetID.flatMap { selectedAssetIDs.contains($0) ? $0 : nil } ?? selectedAssets.first?.id
            statusMessage = "Tagged \(ids.count) selected asset\(ids.count == 1 ? "" : "s") with \(tag.namespace):\(tag.value)."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func removeUserTag(_ tag: AssetTag, from asset: DesignAsset) {
        guard tag.source == "user", tag.protected, let store else { return }
        do {
            try store.deleteUserTag(assetID: asset.id, namespace: tag.namespace, value: tag.value)
            try reloadPreservingSelection()
            statusMessage = "Removed tag \(tag.namespace):\(tag.value)."
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
