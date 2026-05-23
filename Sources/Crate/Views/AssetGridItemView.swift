//
//  AssetGridItemView.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import SwiftUI

struct AssetGridItemView: View {
    @Environment(AppModel.self) private var model

    let asset: DesignAsset
    let focusGrid: () -> Void

    private let cardPadding: CGFloat = 8
    private let cardRadius: CGFloat = 18
    private var previewRadius: CGFloat { cardRadius - cardPadding }

    var isSelected: Bool {
        model.selectedAssetID == asset.id
    }

    var isPartOfSelection: Bool {
        model.selectedAssetIDs.contains(asset.id)
    }

    var isFavorite: Bool {
        model.isFavorite(asset)
    }

    var body: some View {
        Button {
            focusGrid()
            model.handleGridSelection(of: asset, in: model.filteredAssets)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                CratePreviewSurface(cornerRadius: previewRadius) {
                    ThumbnailImage(url: asset.thumbnailURL ?? asset.primaryVariant?.fileURL)
                }
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if isPartOfSelection {
                        RoundedRectangle(cornerRadius: previewRadius, style: .continuous)
                            .stroke(CrateTheme.accent, lineWidth: isSelected ? 2 : 1.5)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(asset.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        Text(asset.kind.capitalized)
                        if asset.hasAlpha {
                            Text("alpha")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }
            .padding(cardPadding)
            .background(isPartOfSelection ? CrateTheme.selectedSurface : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                    .stroke(isPartOfSelection ? CrateTheme.accent.opacity(0.2) : Color.clear)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(asset.displayName)
        .accessibilityValue(asset.kind)
        .overlay(alignment: .topTrailing) {
            Button {
                model.toggleFavorite(asset)
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 13, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isFavorite ? Color.red : .secondary)
                    .frame(width: 26, height: 26)
                    .background(.thinMaterial, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(CrateTheme.faintHairline)
                    }
            }
            .buttonStyle(.plain)
            .help(isFavorite ? "Remove Favorite" : "Favorite")
            .padding(11)
        }
        .overlay(alignment: .topLeading) {
            if isPartOfSelection {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(CrateTheme.accent)
                    .frame(width: 28, height: 28)
                    .background(.thinMaterial, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(CrateTheme.faintHairline)
                    }
                    .padding(11)
            }
        }
        .contextMenu {
            if isPartOfSelection && model.selectedAssetCount > 1 {
                Button("Add \(model.selectedAssetCount) Selected to Cart") {
                    model.addSelectedToCart()
                }
                Button(model.selectedAssetsAreAllFavorites ? "Unfavorite Selected" : "Favorite Selected") {
                    model.setSelectedFavorite(!model.selectedAssetsAreAllFavorites)
                }
                Button("Export Selected") {
                    Task { await model.exportSelectedAssetsToFolder() }
                }
                Button("Clear Selection") {
                    model.clearSelection()
                }
            } else {
                Button(isFavorite ? "Remove Favorite" : "Favorite") {
                    model.toggleFavorite(asset)
                }
                Button("Add to Cart") { model.addToCart(asset) }
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
