//
//  AssetListBrowserView.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-24.
//

import SwiftUI

struct AssetListBrowserView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        GeometryReader { proxy in
            let isCompact = proxy.size.width < 720

            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        ForEach(model.filteredAssets) { asset in
                            AssetListRow(asset: asset, isCompact: isCompact)
                            Divider()
                                .padding(.leading, isCompact ? 72 : 88)
                        }
                    } header: {
                        AssetListHeader(isCompact: isCompact)
                    }
                }
            }
            .background(Color(nsColor: .textBackgroundColor).opacity(0.22))
        }
    }
}

private struct AssetListHeader: View {
    let isCompact: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("Asset")
                .frame(maxWidth: .infinity, alignment: .leading)
            if !isCompact {
                Text("Pack")
                    .frame(width: 150, alignment: .leading)
                Text("Size")
                    .frame(width: 86, alignment: .trailing)
            }
            Text("Quality")
                .frame(width: isCompact ? 68 : 92, alignment: .leading)
            Text("Bytes")
                .frame(width: isCompact ? 68 : 78, alignment: .trailing)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

private struct AssetListRow: View {
    @Environment(AppModel.self) private var model

    let asset: DesignAsset
    let isCompact: Bool

    private var variant: AssetVariant? { asset.primaryVariant }
    private var isFocused: Bool { model.selectedAssetID == asset.id }
    private var isSelected: Bool { model.selectedAssetIDs.contains(asset.id) }
    private var qualityTags: [AssetTag] { asset.tags.filter { $0.namespace == "quality" } }

    var body: some View {
        Button {
            model.handleGridSelection(of: asset, in: model.filteredAssets)
        } label: {
            HStack(spacing: 12) {
                CratePreviewSurface(cornerRadius: 6) {
                    ThumbnailImage(url: asset.thumbnailURL ?? variant?.fileURL)
                }
                .frame(width: isCompact ? 48 : 58, height: isCompact ? 48 : 58)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(asset.displayName)
                            .font(.callout)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        if asset.hasAlpha {
                            CrateChip(text: "alpha")
                        }
                    }
                    HStack(spacing: 6) {
                        Text(asset.kind.capitalized)
                        if let variant {
                            Text("\(variant.width) x \(variant.height)")
                        }
                        if isCompact {
                            Text(packName)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !isCompact {
                    Text(packName)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(width: 150, alignment: .leading)

                    Text(variant.map { "\($0.width) x \($0.height)" } ?? "Unknown")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(width: 86, alignment: .trailing)
                }

                qualityBadge
                    .frame(width: isCompact ? 68 : 92, alignment: .leading)

                Text(byteCount)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: isCompact ? 68 : 78, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(isSelected ? CrateTheme.selectedSurface : Color.clear)
            .overlay(alignment: .leading) {
                if isFocused {
                    Rectangle()
                        .fill(CrateTheme.accent)
                        .frame(width: 3)
                }
            }
        }
        .buttonStyle(.plain)
        .assetBrowserItemActions(asset: asset)
    }

    private var packName: String {
        model.packs.first(where: { $0.id == asset.packID })?.displayName ?? asset.packID
    }

    private var byteCount: String {
        guard let byteCount = variant?.byteCount else { return "-" }
        return ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }

    @ViewBuilder
    private var qualityBadge: some View {
        if qualityTags.isEmpty {
            Text("Clean")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Label("\(qualityTags.count)", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .help(qualityTags.map { QualityWarningCatalog.title(for: $0.value) }.joined(separator: ", "))
        }
    }
}
