//
//  AppModel+Cart.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import Foundation

extension AppModel {
    var cartAssets: [DesignAsset] {
        cartItems.compactMap { assetsByID[$0.assetID] }
    }

    func addToCart(_ asset: DesignAsset) {
        guard !cartItems.contains(where: { $0.assetID == asset.id }) else { return }
        cartItems.append(CartItem(id: UUID().uuidString, assetID: asset.id, addedAt: Date()))
        usedAssetIDs.insert(asset.id)
        saveCart()
        try? store?.recordUsage(assetID: asset.id, event: "carted")
        refreshAfterCartChange()
    }

    func addSelectedToCart() {
        let assets = selectedAssets
        guard !assets.isEmpty else { return }

        var existing = Set(cartItems.map(\.assetID))
        var added = 0
        for asset in assets where !existing.contains(asset.id) {
            cartItems.append(CartItem(id: UUID().uuidString, assetID: asset.id, addedAt: Date()))
            usedAssetIDs.insert(asset.id)
            existing.insert(asset.id)
            try? store?.recordUsage(assetID: asset.id, event: "carted")
            added += 1
        }

        saveCart()
        refreshAfterCartChange()
        statusMessage = added == 0
            ? "Selected assets are already in the cart."
            : "Added \(added) selected asset\(added == 1 ? "" : "s") to the cart."
    }

    func removeFromCart(_ assetID: String) {
        cartItems.removeAll { $0.assetID == assetID }
        saveCart()
        refreshAfterCartChange()
    }

    func clearCart() {
        cartItems.removeAll()
        saveCart()
        refreshAfterCartChange()
    }

    func saveCartAsCollection() {
        guard !cartItems.isEmpty, let store else { return }
        let name = "Cart \(DateFormatter.collectionName.string(from: Date()))"
        let collection = AssetCollection(
            id: "collection-\(UUID().uuidString)",
            name: name,
            coverAssetID: cartItems.first?.assetID,
            createdAt: Date(),
            assetIDs: cartItems.map(\.assetID)
        )

        do {
            try store.saveCollection(collection)
            try reload()
            statusMessage = "Saved collection: \(name)"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func exportCartToFolder() async {
        guard let paths, !cartItems.isEmpty else {
            statusMessage = "Cart is empty. Very avant-garde, but impossible to export."
            return
        }
        do {
            let url = try ExportService.exportCartFolder(items: cartItems, assetsByID: assetsByID, paths: paths)
            lastExportURL = url
            statusMessage = "Exported cart to \(url.path)"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func exportCartToZip() async {
        guard let paths, !cartItems.isEmpty else {
            statusMessage = "Cart is empty. Add something first."
            return
        }
        do {
            let url = try ExportService.exportCartZip(items: cartItems, assetsByID: assetsByID, paths: paths)
            lastExportURL = url
            statusMessage = "Exported zip to \(url.path)"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func exportSelectedAssetsToFolder() async {
        guard let paths, !selectedAssets.isEmpty else {
            statusMessage = "Select assets before exporting."
            return
        }

        do {
            let url = try ExportService.exportAssetsFolder(assets: selectedAssets, paths: paths)
            lastExportURL = url
            statusMessage = "Exported \(selectedAssetCount) selected asset\(selectedAssetCount == 1 ? "" : "s") to \(url.path)"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func revealLastExport() {
        guard let lastExportURL else { return }
        AssetActions.reveal(lastExportURL)
    }
}

private extension AppModel {
    func saveCart() {
        do {
            try store?.saveCart(cartItems)
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

private extension DateFormatter {
    static let collectionName: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
