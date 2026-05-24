//
//  AssetFilmstripBrowserView.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-24.
//

import AppKit
import SwiftUI

struct AssetFilmstripBrowserView: View {
    @Environment(AppModel.self) private var model
    @FocusState private var isFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width >= 860
            let previewHeight = max(300, min(isWide ? 520 : 380, proxy.size.height - 168))

            VStack(spacing: 0) {
                if let asset = focusedAsset {
                    mainContent(asset: asset, isWide: isWide, previewHeight: previewHeight)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                    Divider()

                    filmstrip(selectedAssetID: asset.id)
                } else {
                    ContentUnavailableView(
                        "Nothing to preview",
                        systemImage: "film.stack",
                        description: Text("The current filters do not have any assets.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color(nsColor: .textBackgroundColor).opacity(0.12))
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .onAppear {
                isFocused = true
            }
            .onKeyPress(.leftArrow) {
                moveSelection(by: -1)
            }
            .onKeyPress(.rightArrow) {
                moveSelection(by: 1)
            }
        }
    }

    private var focusedAsset: DesignAsset? {
        if let selectedAssetID = model.selectedAssetID,
           let asset = model.assetsByID[selectedAssetID],
           model.filteredAssets.contains(where: { $0.id == selectedAssetID }) {
            return asset
        }
        return model.filteredAssets.first
    }

    private func mainContent(asset: DesignAsset, isWide: Bool, previewHeight: CGFloat) -> some View {
        let variant = selectedVariant(for: asset)

        return Group {
            if isWide {
                HStack(alignment: .top, spacing: 18) {
                    previewPane(asset: asset, variant: variant, height: previewHeight)
                        .frame(maxWidth: .infinity, alignment: .topLeading)

                    AssetFilmstripDetailsPanel(asset: asset, variant: variant, isCompact: false)
                        .frame(width: 286, alignment: .topLeading)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        previewPane(asset: asset, variant: variant, height: previewHeight)
                        AssetFilmstripDetailsPanel(asset: asset, variant: variant, isCompact: true)
                    }
                }
            }
        }
        .padding(isWide ? 20 : 14)
    }

    private func previewPane(asset: DesignAsset, variant: AssetVariant?, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(asset.displayName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        CrateChip(text: asset.kind.capitalized, isSelected: true)
                        if asset.hasAlpha {
                            CrateChip(text: "alpha")
                        }
                    }
                }

                Spacer(minLength: 10)

                Button {
                    model.toggleFavorite(asset)
                } label: {
                    Image(systemName: model.isFavorite(asset) ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(model.isFavorite(asset) ? Color.red : .secondary)
                        .frame(width: 30, height: 28)
                }
                .buttonStyle(.plain)
                .help(model.isFavorite(asset) ? "Remove Favorite" : "Favorite")
            }

            InteractiveAssetPreview(url: variant?.fileURL ?? asset.primaryVariant?.fileURL, height: height)
                .assetBrowserItemActions(asset: asset)
        }
    }

    private func filmstrip(selectedAssetID: String) -> some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(model.filteredAssets) { asset in
                        AssetFilmstripThumbnail(asset: asset)
                            .id(asset.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(.bar)
            .frame(height: 108)
            .task(id: selectedAssetID) {
                scrollToSelectedAsset(selectedAssetID, with: scrollProxy)
            }
        }
    }

    private func selectedVariant(for asset: DesignAsset) -> AssetVariant? {
        if asset.id == model.selectedAssetID, let selectedVariant = model.selectedVariant {
            return selectedVariant
        }
        if let variantID = model.selectedVariantByAsset[asset.id] {
            return asset.variants.first(where: { $0.id == variantID }) ?? asset.primaryVariant
        }
        return asset.primaryVariant
    }

    private func moveSelection(by delta: Int) -> KeyPress.Result {
        let assets = model.filteredAssets
        guard !assets.isEmpty else { return .ignored }

        let currentIndex = model.selectedAssetID.flatMap { selectedID in
            assets.firstIndex { $0.id == selectedID }
        } ?? 0
        let targetIndex = max(0, min(assets.count - 1, currentIndex + delta))
        guard assets.indices.contains(targetIndex) else { return .handled }

        let target = assets[targetIndex]
        guard target.id != model.selectedAssetID else { return .handled }

        let modifiers = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers.contains(.shift) {
            model.selectRange(to: target, in: assets, extending: modifiers.contains(.command))
        } else {
            model.select(target)
        }
        return .handled
    }

    @MainActor
    private func scrollToSelectedAsset(_ selectedAssetID: String, with scrollProxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.18)) {
            scrollProxy.scrollTo(selectedAssetID, anchor: .center)
        }
    }
}

private struct AssetFilmstripDetailsPanel: View {
    @Environment(AppModel.self) private var model

    let asset: DesignAsset
    let variant: AssetVariant?
    let isCompact: Bool

    private var packName: String {
        model.packs.first(where: { $0.id == asset.packID })?.displayName ?? asset.packID
    }

    private var qualityTags: [AssetTag] {
        asset.tags
            .filter { $0.namespace == "quality" }
            .sorted { $0.value < $1.value }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            actionGroup

            VStack(alignment: .leading, spacing: 8) {
                FilmstripDetailRow(title: "Pack", value: packName)
                FilmstripDetailRow(title: "Name", value: asset.normalizedName)
                if let variant {
                    FilmstripDetailRow(title: "Size", value: "\(variant.width) x \(variant.height)")
                    FilmstripDetailRow(title: "File", value: variant.fileExtension.uppercased())
                    FilmstripDetailRow(
                        title: "Bytes",
                        value: ByteCountFormatter.string(fromByteCount: variant.byteCount, countStyle: .file)
                    )
                }
            }

            if asset.variants.count > 1 {
                variantPicker
            }

            if !qualityTags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quality")
                        .font(.headline)

                    FlowLayout(spacing: 6) {
                        ForEach(qualityTags.prefix(5)) { tag in
                            CrateChip(text: QualityWarningCatalog.title(for: tag.value))
                        }
                    }
                }
            }
        }
        .padding(isCompact ? 0 : 12)
        .background(isCompact ? Color.clear : CrateTheme.subtleFill)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            if !isCompact {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(CrateTheme.faintHairline)
            }
        }
    }

    private var actionGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Actions")
                .font(.headline)

            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    actionButton("Cart", "cart.badge.plus") {
                        model.addToCart(asset)
                    }
                    actionButton(model.isFavorite(asset) ? "Unfavorite" : "Favorite", model.isFavorite(asset) ? "heart.slash" : "heart") {
                        model.toggleFavorite(asset)
                    }
                }
                GridRow {
                    actionButton("Reveal", "folder") {
                        if let url = variant?.fileURL { AssetActions.reveal(url) }
                    }
                    actionButton("Copy Path", "doc.on.doc") {
                        if let url = variant?.fileURL { AssetActions.copyPath(url) }
                    }
                }
                GridRow {
                    actionButton("Open", "arrow.up.right.square") {
                        if let url = variant?.fileURL { AssetActions.open(url) }
                    }
                    actionButton("Copy Image", "photo.on.rectangle") {
                        if let url = variant?.fileURL { AssetActions.copyImage(url) }
                    }
                }
                GridRow {
                    PixelmatorActionControl(scope: .asset(asset), compact: true)
                        .gridCellColumns(2)
                }
            }
        }
    }

    private var variantPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Variants")
                .font(.headline)

            VStack(spacing: 6) {
                ForEach(asset.variants) { candidate in
                    Button {
                        model.selectVariant(candidate, for: asset)
                    } label: {
                        VariantRow(
                            variant: candidate,
                            isSelected: variant?.id == candidate.id
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func actionButton(_ title: String, _ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

private struct FilmstripDetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .leading)
            Text(value)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.callout)
    }
}

private struct AssetFilmstripThumbnail: View {
    @Environment(AppModel.self) private var model

    let asset: DesignAsset

    private var isFocused: Bool {
        model.selectedAssetID == asset.id
    }

    private var isSelected: Bool {
        model.selectedAssetIDs.contains(asset.id)
    }

    var body: some View {
        Button {
            model.handleGridSelection(of: asset, in: model.filteredAssets)
        } label: {
            CratePreviewSurface(cornerRadius: 8) {
                ThumbnailImage(url: asset.thumbnailURL ?? asset.primaryVariant?.fileURL)
            }
            .frame(width: 78, height: 78)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isFocused ? CrateTheme.accent : Color.clear, lineWidth: 2)
            }
            .overlay(alignment: .topLeading) {
                if isSelected {
                    Image(systemName: isFocused ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.system(size: 15, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(CrateTheme.accent)
                        .padding(6)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(asset.displayName)
        .assetBrowserItemActions(asset: asset)
    }
}
