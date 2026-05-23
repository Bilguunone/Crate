//
//  InspectorView.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-22.
//

import SwiftUI

struct InspectorView: View {
    @Environment(AppModel.self) private var model
    @State private var tagDraft = ""
    @State private var deferredInspectorAssetID: String?

    var body: some View {
        Group {
            if model.selectedAssetCount > 1 {
                BulkSelectionInspectorView()
            } else if let asset = model.selectedAsset {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        preview(asset)
                        actions(asset)
                        metadata(asset)
                        qualityWarnings(asset)
                        userTags(asset)
                        deferredSections(asset)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .task(id: asset.id) {
                        deferredInspectorAssetID = nil
                        try? await Task.sleep(nanoseconds: 120_000_000)
                        guard !Task.isCancelled else { return }
                        deferredInspectorAssetID = asset.id
                    }
                }
            } else {
                ContentUnavailableView(
                    "Nothing selected",
                    systemImage: "cursorarrow.click",
                    description: Text("Pick an asset to inspect variants, tags, and export actions.")
                )
                .padding()
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func preview(_ asset: DesignAsset) -> some View {
        VStack(alignment: .leading, spacing: 12) {
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
                    Spacer(minLength: 8)
                    favoriteButton(asset)
                }
            }

            InteractiveAssetPreview(url: model.selectedVariant?.fileURL)
        }
    }

    private func actions(_ asset: DesignAsset) -> some View {
        InspectorSection(title: "Actions") {
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    actionButton("Cart", "cart.badge.plus") { model.addToCart(asset) }
                    actionButton(model.isFavorite(asset) ? "Unfavorite" : "Favorite", model.isFavorite(asset) ? "heart.slash" : "heart") {
                        model.toggleFavorite(asset)
                    }
                }
                GridRow {
                    actionButton("Reveal", "folder") {
                        if let url = model.selectedVariant?.fileURL { AssetActions.reveal(url) }
                    }
                    actionButton("Copy Path", "doc.on.doc") {
                        if let url = model.selectedVariant?.fileURL { AssetActions.copyPath(url) }
                    }
                }
                GridRow {
                    actionButton("Copy Image", "photo.on.rectangle") {
                        if let url = model.selectedVariant?.fileURL { AssetActions.copyImage(url) }
                    }
                    actionButton("Open", "arrow.up.right.square") {
                        if let url = model.selectedVariant?.fileURL { AssetActions.open(url) }
                    }
                }
                GridRow {
                    PixelmatorActionControl(scope: .asset(asset), compact: true)
                        .gridCellColumns(2)
                }
            }
        }
    }

    private func metadata(_ asset: DesignAsset) -> some View {
        InspectorSection(title: "Details") {
            VStack(spacing: 7) {
                InspectorMetadataRow("Name", asset.normalizedName)
                InspectorMetadataRow("Kind", asset.kind)
                InspectorMetadataRow("Pack", model.packs.first(where: { $0.id == asset.packID })?.displayName ?? asset.packID)
                if let variant = model.selectedVariant {
                    InspectorMetadataRow("Size", "\(variant.width) x \(variant.height)")
                    InspectorMetadataRow("Alpha", variant.hasAlpha ? "yes" : "no")
                    InspectorMetadataRow("File", variant.fileExtension.uppercased())
                    InspectorMetadataRow("Bytes", ByteCountFormatter.string(fromByteCount: variant.byteCount, countStyle: .file))
                }
            }
        }
    }

    private func userTags(_ asset: DesignAsset) -> some View {
        InspectorSection(title: "Your Tags") {
            UserTagEditor(asset: asset, draft: $tagDraft)
        }
    }

    @ViewBuilder
    private func qualityWarnings(_ asset: DesignAsset) -> some View {
        let qualityTags = asset.tags
            .filter { $0.namespace == "quality" }
            .sorted {
                let leftIndex = QualityWarningCatalog.orderedValues.firstIndex(of: $0.value) ?? Int.max
                let rightIndex = QualityWarningCatalog.orderedValues.firstIndex(of: $1.value) ?? Int.max
                if leftIndex == rightIndex { return $0.value < $1.value }
                return leftIndex < rightIndex
            }
        let clusters = model.selectedAssetID == asset.id ? model.selectedDuplicateClusters : model.duplicateClusters(for: asset)

        if !qualityTags.isEmpty || !clusters.isEmpty {
            InspectorSection(title: "Quality Warnings") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(qualityTags) { tag in
                        QualityWarningRow(
                            title: QualityWarningCatalog.title(for: tag.value),
                            detail: QualityWarningCatalog.detail(for: tag.value),
                            systemImage: QualityWarningCatalog.systemImage(for: tag.value)
                        )
                    }

                    if !clusters.isEmpty {
                        QualityWarningRow(
                            title: QualityWarningCatalog.title(for: "suspicious-duplicate"),
                            detail: "\(clusters.count) duplicate \(clusters.count == 1 ? "group" : "groups") found",
                            systemImage: QualityWarningCatalog.systemImage(for: "suspicious-duplicate")
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func deferredSections(_ asset: DesignAsset) -> some View {
        if deferredInspectorAssetID == asset.id {
            autoTags(asset)
            variants(asset)
            duplicateWatch(asset)
            similar(asset)
        } else {
            InspectorDeferredSectionPlaceholder()
        }
    }

    private func autoTags(_ asset: DesignAsset) -> some View {
        let tags = asset.tags
            .filter { $0.namespace != "quality" && !($0.source == "user" && $0.protected) }
            .sorted { $0.namespace == $1.namespace ? $0.value < $1.value : $0.namespace < $1.namespace }

        return InspectorSection(title: "Auto Tags") {
            if tags.isEmpty {
                Text("No auto tags")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(tags) { tag in
                        CrateChip(text: "\(tag.namespace):\(tag.value)")
                    }
                }
            }
        }
    }

    private func favoriteButton(_ asset: DesignAsset) -> some View {
        Button {
            model.toggleFavorite(asset)
        } label: {
            Image(systemName: model.isFavorite(asset) ? "heart.fill" : "heart")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(model.isFavorite(asset) ? Color.red : .secondary)
                .frame(width: 28, height: 24)
        }
        .buttonStyle(.plain)
        .help(model.isFavorite(asset) ? "Remove Favorite" : "Favorite")
    }

    private func variants(_ asset: DesignAsset) -> some View {
        InspectorSection(title: "Variants") {
            VStack(spacing: 6) {
                ForEach(asset.variants) { variant in
                    Button {
                        model.selectVariant(variant, for: asset)
                    } label: {
                        VariantRow(
                            variant: variant,
                            isSelected: model.selectedVariant?.id == variant.id
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func duplicateWatch(_ asset: DesignAsset) -> some View {
        let clusters = model.selectedAssetID == asset.id ? model.selectedDuplicateClusters : model.duplicateClusters(for: asset)
        if !clusters.isEmpty {
            InspectorSection(title: "Duplicate Watch") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(clusters.prefix(3)) { cluster in
                        VStack(alignment: .leading, spacing: 5) {
                            Label(duplicateLabel(cluster), systemImage: duplicateIcon(cluster.reason))
                                .font(.callout)
                                .foregroundStyle(cluster.reason == .nearDuplicate ? .orange : .primary)

                            ForEach(cluster.assetIDs.filter { $0 != asset.id }.prefix(4), id: \.self) { id in
                                if let match = model.assetsByID[id] {
                                    Button {
                                        model.select(match)
                                    } label: {
                                        SimilarAssetRow(asset: match)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func similar(_ asset: DesignAsset) -> some View {
        InspectorSection(title: "Similar") {
            let similar = model.selectedAssetID == asset.id ? model.selectedSimilarAssets : model.similarAssets(to: asset)
            if similar.isEmpty {
                Text(model.isFindingSimilarAssets ? "Finding similar assets..." : "No close matches yet")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(similar.prefix(8)) { item in
                        Button {
                            model.select(item)
                        } label: {
                            SimilarAssetRow(asset: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func actionButton(_ title: String, _ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func duplicateLabel(_ cluster: DuplicateCluster) -> String {
        switch cluster.reason {
        case .exactFile:
            "Exact duplicate"
        case .sameImage:
            "Same image"
        case .jpgPngVariant:
            "JPG/PNG variant"
        case .nearDuplicate:
            cluster.distance.map { "Near duplicate · distance \($0)" } ?? "Near duplicate"
        }
    }

    private func duplicateIcon(_ reason: DuplicateReason) -> String {
        switch reason {
        case .exactFile:
            "equal.square"
        case .sameImage:
            "photo.on.rectangle"
        case .jpgPngVariant:
            "rectangle.2.swap"
        case .nearDuplicate:
            "exclamationmark.triangle"
        }
    }
}

private struct QualityWarningRow: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
