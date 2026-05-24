//
//  AssetBrowserItemActions.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-24.
//

import SwiftUI

extension View {
    func assetBrowserItemActions(asset: DesignAsset) -> some View {
        modifier(AssetBrowserItemActionsModifier(asset: asset))
    }
}

private struct AssetBrowserItemActionsModifier: ViewModifier {
    @Environment(AppModel.self) private var model

    let asset: DesignAsset

    func body(content: Content) -> some View {
        content
            .contextMenu {
                if model.selectedAssetIDs.contains(asset.id), model.selectedAssetCount > 1 {
                    Button("Add \(model.selectedAssetCount) Selected to Cart") {
                        model.addSelectedToCart()
                    }
                    Button(model.selectedAssetsAreAllFavorites ? "Unfavorite Selected" : "Favorite Selected") {
                        model.setSelectedFavorite(!model.selectedAssetsAreAllFavorites)
                    }
                    Button("Export Selected") {
                        Task { await model.exportSelectedAssetsToFolder() }
                    }
                    if model.hasOpenPixelmatorProject {
                        Button("Add Selected to Pixelmator") {
                            model.sendSelectedToOpenPixelmatorProject()
                        }
                        .disabled(model.pixelmatorFrontDocumentURL == nil || model.isSendingToPixelmator)
                    }
                    Button("Add Selected to Pixelmator Document...") {
                        model.sendSelectedToChosenPixelmatorDocument()
                    }
                    .disabled(model.isSendingToPixelmator)
                    Button("Clear Selection") {
                        model.clearSelection()
                    }
                } else {
                    Button(model.isFavorite(asset) ? "Remove Favorite" : "Favorite") {
                        model.toggleFavorite(asset)
                    }
                    Button("Add to Cart") {
                        model.addToCart(asset)
                    }
                    if model.hasOpenPixelmatorProject {
                        Button("Add to Pixelmator") {
                            model.sendAssetToOpenPixelmatorProject(asset)
                        }
                        .disabled(model.pixelmatorFrontDocumentURL == nil || model.isSendingToPixelmator)
                    }
                    Button("Add to Pixelmator Document...") {
                        model.sendAssetToChosenPixelmatorDocument(asset)
                    }
                    .disabled(model.isSendingToPixelmator)
                }

                if let url = asset.primaryVariant?.fileURL {
                    Button("Reveal in Finder") { AssetActions.reveal(url) }
                    Button("Copy Path") { AssetActions.copyPath(url) }
                    Button("Copy Image") { AssetActions.copyImage(url) }
                }

                Divider()

                Button("Remove Asset", role: .destructive) {
                    model.requestRemoveAssets([asset.id])
                }
            }
            .onDrag {
                guard let url = asset.primaryVariant?.fileURL else { return NSItemProvider() }
                return NSItemProvider(contentsOf: url) ?? NSItemProvider(object: url as NSURL)
            }
    }
}
