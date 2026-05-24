//
//  AssetCompareBrowserView.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-24.
//

import SwiftUI

struct AssetCompareBrowserView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                compareHeader
                    .padding(.horizontal, proxy.size.width < 700 ? 14 : 20)
                    .padding(.vertical, 12)

                Divider()

                compareStage(width: proxy.size.width)

                Divider()

                CompareAssetPickerStrip()
                    .frame(height: proxy.size.width < 700 ? 116 : 128)
            }
            .background(Color(nsColor: .textBackgroundColor).opacity(0.12))
            .task {
                model.prepareComparisonSelection()
            }
        }
    }

    private var compareAssets: [DesignAsset] {
        Array(model.selectedAssets.prefix(8))
    }

    private var compareHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Compare Desk")
                    .font(.headline)
                Text(compareSubtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                model.prepareComparisonSelection()
            } label: {
                Label("Auto Pick", systemImage: "sparkles")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Pick a useful starter comparison from the current results")

            Button {
                model.clearSelection()
            } label: {
                Label("Clear", systemImage: "xmark.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(model.selectedAssetIDs.isEmpty)
            .help("Clear the comparison set")
        }
    }

    private var compareSubtitle: String {
        if compareAssets.isEmpty {
            return "Pick assets from the strip below."
        }
        if compareAssets.count == 1 {
            return "1 of 8 selected. Add another asset from the strip below."
        }
        return "\(compareAssets.count) of 8 selected. Click a card to focus it, or use the strip to add more."
    }

    private func compareStage(width: CGFloat) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if compareAssets.isEmpty {
                    CompareEmptyStage()
                } else {
                    LazyVGrid(columns: compareColumns(for: width), spacing: width < 700 ? 12 : 14) {
                        ForEach(Array(compareAssets.enumerated()), id: \.element.id) { index, asset in
                            AssetCompareCard(asset: asset, index: index)
                        }

                        if compareAssets.count == 1 {
                            CompareAddAnotherCard()
                        }
                    }
                }
            }
            .padding(width < 700 ? 14 : 20)
        }
    }

    private func compareColumns(for width: CGFloat) -> [GridItem] {
        let count: Int
        if compareAssets.count <= 2, width > 780 {
            count = compareAssets.count == 1 ? 2 : 2
        } else if width > 1_240 {
            count = 4
        } else if width > 920 {
            count = 3
        } else if width > 640 {
            count = 2
        } else {
            count = 1
        }
        return Array(repeating: GridItem(.flexible(minimum: 250), spacing: 14), count: max(1, count))
    }
}

private struct AssetCompareCard: View {
    @Environment(AppModel.self) private var model

    let asset: DesignAsset
    let index: Int

    private var variant: AssetVariant? { asset.primaryVariant }
    private var isFocused: Bool { model.selectedAssetID == asset.id }
    private var warnings: [AssetTag] { asset.tags.filter { $0.namespace == "quality" } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            comparePreview

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(asset.displayName)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Button {
                        model.toggleFavorite(asset)
                    } label: {
                        Image(systemName: model.isFavorite(asset) ? "heart.fill" : "heart")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(model.isFavorite(asset) ? Color.red : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(model.isFavorite(asset) ? "Remove Favorite" : "Favorite")
                }

                Text(packName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            VStack(spacing: 7) {
                CompareMetricRow("Size", value: variant.map { "\($0.width) x \($0.height)" } ?? "Unknown")
                CompareMetricRow("Ratio", value: aspectRatioLabel)
                CompareMetricRow("Alpha", value: asset.hasAlpha ? "Yes" : "No")
                CompareMetricRow("File", value: variant?.fileExtension.uppercased() ?? "-")
                CompareMetricRow("Bytes", value: byteCount)
            }

            if !warnings.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(warnings.prefix(3)) { warning in
                        CrateChip(text: QualityWarningCatalog.title(for: warning.value))
                    }
                }
            }

            HStack(spacing: 8) {
                Button {
                    model.addToCart(asset)
                } label: {
                    Label("Cart", systemImage: "cart.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(role: .destructive) {
                    model.removeAssetFromComparison(asset)
                } label: {
                    Label("Remove", systemImage: "minus.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(isFocused ? CrateTheme.selectedSurface : CrateTheme.subtleFill)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isFocused ? CrateTheme.accent.opacity(0.65) : CrateTheme.faintHairline, lineWidth: isFocused ? 1.5 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            model.focusAssetInSelection(asset)
        }
        .assetBrowserItemActions(asset: asset)
    }

    private var comparePreview: some View {
        CratePreviewSurface(cornerRadius: 10) {
            ThumbnailImage(url: asset.thumbnailURL ?? variant?.fileURL)
        }
        .aspectRatio(1.14, contentMode: .fit)
        .overlay(alignment: .topLeading) {
            Text(compareLetter)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(CrateTheme.accent, in: Capsule())
                .padding(8)
        }
        .overlay(alignment: .topTrailing) {
            if isFocused {
                Image(systemName: "scope")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CrateTheme.accent)
                    .padding(8)
            }
        }
    }

    private var compareLetter: String {
        let scalars = UnicodeScalar(65 + index).map(String.init) ?? "#"
        return scalars
    }

    private var packName: String {
        model.packs.first(where: { $0.id == asset.packID })?.displayName ?? asset.packID
    }

    private var byteCount: String {
        guard let byteCount = variant?.byteCount else { return "-" }
        return ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }

    private var aspectRatioLabel: String {
        guard let variant, variant.height > 0 else { return "-" }
        let ratio = Double(variant.width) / Double(variant.height)
        return String(format: "%.2f", ratio)
    }
}

private struct CompareMetricRow: View {
    let title: String
    let value: String

    init(_ title: String, value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)
            Text(value)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.caption)
    }
}

private struct CompareAddAnotherCard: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "plus.rectangle.on.rectangle")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(CrateTheme.accent)

            Text("Add another asset")
                .font(.headline)

            Text("Use the strip below to build the comparison set.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .padding(20)
        .background(CrateTheme.subtleFill)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
                .foregroundStyle(CrateTheme.faintHairline)
        }
    }
}

private struct CompareEmptyStage: View {
    var body: some View {
        ContentUnavailableView(
            "Pick assets to compare",
            systemImage: "rectangle.split.3x1",
            description: Text("Choose assets from the strip below. Two to four is the sweet spot; eight is for when you enjoy chaos.")
        )
        .frame(maxWidth: .infinity, minHeight: 280)
    }
}

private struct CompareAssetPickerStrip: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label("Pick from current results", systemImage: "plus.square.on.square")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(model.selectedAssetCount)/8")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(model.filteredAssets) { asset in
                            ComparePickerThumbnail(asset: asset)
                                .id(asset.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
                .task(id: model.selectedAssetID) {
                    guard let selectedAssetID = model.selectedAssetID else { return }
                    withAnimation(.easeOut(duration: 0.18)) {
                        scrollProxy.scrollTo(selectedAssetID, anchor: .center)
                    }
                }
            }
        }
        .background(.bar)
    }
}

private struct ComparePickerThumbnail: View {
    @Environment(AppModel.self) private var model

    let asset: DesignAsset

    private var isSelected: Bool { model.selectedAssetIDs.contains(asset.id) }
    private var isFocused: Bool { model.selectedAssetID == asset.id }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                if isSelected {
                    model.focusAssetInSelection(asset)
                } else {
                    model.addAssetToComparison(asset)
                }
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    CratePreviewSurface(cornerRadius: 8) {
                        ThumbnailImage(url: asset.thumbnailURL ?? asset.primaryVariant?.fileURL)
                    }
                    .frame(width: 76, height: 64)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isFocused ? CrateTheme.accent : Color.clear, lineWidth: 2)
                    }

                    Text(asset.displayName)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .frame(width: 76, alignment: .leading)
                }
                .padding(6)
                .background(isSelected ? CrateTheme.selectedSurface : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .help(isSelected ? "Focus this comparison asset" : "Add to comparison")

            if isSelected {
                Button {
                    model.removeAssetFromComparison(asset)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .help("Remove from comparison")
            }
        }
        .assetBrowserItemActions(asset: asset)
    }
}
