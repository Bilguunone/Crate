//
//  AssetGridView.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-22.
//

import AppKit
import SwiftUI

struct AssetGridView: View {
    @Environment(AppModel.self) private var model
    @FocusState private var isGridFocused: Bool
    @State private var itemFrames: [String: CGRect] = [:]
    @State private var marqueeState: AssetGridMarqueeState?
    @State private var isIgnoringMarqueeDrag = false

    private let gridCoordinateSpace = "crate-asset-grid"

    var body: some View {
        GeometryReader { outerProxy in
            let metrics = gridMetrics(for: outerProxy.size.width)

            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text(summary)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    BrowserViewModeControl()
                    if let pack = model.selectedPack {
                        Button(role: .destructive) {
                            model.requestRemovePack(pack)
                        } label: {
                            if metrics.isCompact {
                                Image(systemName: "trash")
                            } else {
                                Label("Remove Pack", systemImage: "trash")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Remove this imported pack from the managed library")
                    }
                    if model.isImporting {
                        Label {
                            Text("Importing")
                        } icon: {
                            ProgressView()
                                .controlSize(.small)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, metrics.horizontalPadding)
                .padding(.vertical, metrics.headerVerticalPadding)

                refinementBar
                    .padding(.horizontal, metrics.horizontalPadding)
                    .padding(.bottom, metrics.refinementBottomPadding)

                Divider()

                browserContent(metrics: metrics)
            }
        }
    }

    private var title: String {
        switch model.selectedFilter {
        case .all: "Library"
        case .pack(let id): model.packs.first(where: { $0.id == id })?.displayName ?? "Pack"
        case .kind(let kind): kind.capitalized
        case .material(let material): material.capitalized
        case .use(let use): use.replacingOccurrences(of: "-", with: " ").capitalized
        case .alpha: "Transparent Assets"
        case .tag(let namespace, let value): "\(namespace.replacingOccurrences(of: "_", with: " ").capitalized): \(value.capitalized)"
        case .userTag(let namespace, let value): namespace == "user" ? value.capitalized : "\(namespace):\(value)"
        case .smart(let kind): smartTitle(kind)
        case .collection(let id): model.collections.first(where: { $0.id == id })?.name ?? "Collection"
        case .shuffle: "Shuffle 12"
        }
    }

    private var summary: String {
        let count = model.filteredAssets.count
        let total = model.assets.count
        let prefix: String
        if model.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            prefix = "\(count) of \(total) assets"
        } else {
            prefix = "\(count) matches in \(total) assets"
        }
        guard let refinementSummary = model.refinementSummary else { return prefix }
        return "\(prefix) · \(refinementSummary)"
    }

    private var refinementBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                BrowseFilterMenu()

                RefinementMenu(title: "Sort", value: model.sortMode.title, systemImage: "arrow.up.arrow.down") {
                    ForEach(AssetSortMode.allCases) { mode in
                        Button(mode.title) { model.setSortMode(mode) }
                    }
                }

                ActiveFilterChips()

                if !model.filteredAssets.isEmpty {
                    Button {
                        model.selectAllFilteredAssets()
                    } label: {
                        Label("Select All", systemImage: "checkmark.circle")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Select all visible assets")
                }
            }
            .padding(.vertical, 1)
        }
    }

    private func smartTitle(_ kind: SmartCollectionKind) -> String {
        if kind == .similarToSelected,
           let anchorID = model.smartSimilarAnchorID,
           let anchor = model.assetsByID[anchorID] {
            return "Similar to \(anchor.displayName)"
        }
        return kind.title
    }

    @ViewBuilder
    private func browserContent(metrics: AssetGridMetrics) -> some View {
        if model.filteredAssets.isEmpty {
            AssetEmptyState(isLibraryEmpty: model.assets.isEmpty)
        } else {
            switch model.browserViewMode {
            case .grid:
                gridBrowser(metrics: metrics)
            case .filmstrip:
                AssetFilmstripBrowserView()
            case .list:
                AssetListBrowserView()
            case .compare:
                AssetCompareBrowserView()
            }
        }
    }

    private func gridBrowser(metrics: AssetGridMetrics) -> some View {
        GeometryReader { proxy in
            let visibleAssets = model.filteredAssets
            let columnCount = gridColumnCount(for: proxy.size.width, metrics: metrics)

            ScrollViewReader { scrollProxy in
                ZStack(alignment: .topLeading) {
                    ScrollView {
                        LazyVGrid(columns: gridColumns(count: columnCount, metrics: metrics), spacing: metrics.rowSpacing) {
                            ForEach(visibleAssets) { asset in
                                AssetGridItemView(asset: asset) {
                                    isGridFocused = true
                                }
                                .id(asset.id)
                                .assetGridItemFrame(id: asset.id, coordinateSpace: gridCoordinateSpace)
                            }
                        }
                        .padding(metrics.gridPadding)
                    }
                    .onPreferenceChange(AssetGridItemFramePreferenceKey.self) { frames in
                        itemFrames = frames
                    }

                    if let marqueeState {
                        AssetGridSelectionMarquee(rect: marqueeState.rect)
                    }
                }
                .coordinateSpace(name: gridCoordinateSpace)
                .clipped()
                .contentShape(Rectangle())
                .simultaneousGesture(selectionMarqueeGesture(in: visibleAssets))
                .simultaneousGesture(emptyBackgroundTapGesture(in: visibleAssets))
                .focusable()
                .focused($isGridFocused)
                .focusEffectDisabled()
                .onAppear {
                    isGridFocused = true
                }
                .onChange(of: model.selectedAssetID) {
                    guard marqueeState == nil else { return }
                    scrollSelectedAssetIfVisible(in: visibleAssets, with: scrollProxy)
                }
                .onKeyPress(.leftArrow) {
                    moveSelection(.left, in: visibleAssets, columnCount: columnCount, scrollProxy: scrollProxy)
                }
                .onKeyPress(.rightArrow) {
                    moveSelection(.right, in: visibleAssets, columnCount: columnCount, scrollProxy: scrollProxy)
                }
                .onKeyPress(.upArrow) {
                    moveSelection(.up, in: visibleAssets, columnCount: columnCount, scrollProxy: scrollProxy)
                }
                .onKeyPress(.downArrow) {
                    moveSelection(.down, in: visibleAssets, columnCount: columnCount, scrollProxy: scrollProxy)
                }
            }
        }
    }

    private func gridColumns(count: Int, metrics: AssetGridMetrics) -> [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: metrics.itemMinWidth, maximum: metrics.itemMaxWidth), spacing: metrics.gridSpacing),
            count: count
        )
    }

    private func gridColumnCount(for width: CGFloat, metrics: AssetGridMetrics) -> Int {
        let contentWidth = max(metrics.itemMinWidth, width - (metrics.gridPadding * 2))
        let maximumColumns = max(1, Int((contentWidth + metrics.gridSpacing) / (metrics.itemMinWidth + metrics.gridSpacing)))
        let minimumColumns = max(1, Int(ceil((contentWidth + metrics.gridSpacing) / (metrics.itemMaxWidth + metrics.gridSpacing))))
        return max(1, max(minimumColumns, maximumColumns))
    }

    private func gridMetrics(for width: CGFloat) -> AssetGridMetrics {
        if width < 520 {
            return AssetGridMetrics(
                horizontalPadding: 14,
                headerVerticalPadding: 12,
                refinementBottomPadding: 10,
                gridPadding: 14,
                gridSpacing: 12,
                rowSpacing: 12,
                itemMinWidth: 132,
                itemMaxWidth: 188,
                isCompact: true
            )
        }

        return AssetGridMetrics(
            horizontalPadding: 20,
            headerVerticalPadding: 14,
            refinementBottomPadding: 12,
            gridPadding: 20,
            gridSpacing: 16,
            rowSpacing: 14,
            itemMinWidth: 154,
            itemMaxWidth: 220,
            isCompact: false
        )
    }

    private func moveSelection(
        _ direction: GridNavigationDirection,
        in assets: [DesignAsset],
        columnCount: Int,
        scrollProxy: ScrollViewProxy
    ) -> KeyPress.Result {
        guard !assets.isEmpty else { return .ignored }

        let currentIndex = model.selectedAssetID.flatMap { selectedID in
            assets.firstIndex { $0.id == selectedID }
        }

        let targetIndex = navigationTargetIndex(
            from: currentIndex,
            direction: direction,
            assetCount: assets.count,
            columnCount: columnCount
        )

        guard assets.indices.contains(targetIndex) else { return .handled }
        let target = assets[targetIndex]
        guard target.id != model.selectedAssetID else { return .handled }

        let modifiers = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers.contains(.shift) {
            model.selectRange(to: target, in: assets, extending: modifiers.contains(.command))
        } else {
            model.select(target)
        }
        withAnimation(.easeOut(duration: 0.16)) {
            scrollProxy.scrollTo(target.id, anchor: .center)
        }
        return .handled
    }

    private func navigationTargetIndex(
        from currentIndex: Int?,
        direction: GridNavigationDirection,
        assetCount: Int,
        columnCount: Int
    ) -> Int {
        guard let currentIndex else { return 0 }
        let rowJump = max(1, columnCount)

        switch direction {
        case .left:
            return max(0, currentIndex - 1)
        case .right:
            return min(assetCount - 1, currentIndex + 1)
        case .up:
            return max(0, currentIndex - rowJump)
        case .down:
            return min(assetCount - 1, currentIndex + rowJump)
        }
    }

    private func scrollSelectedAssetIfVisible(in assets: [DesignAsset], with scrollProxy: ScrollViewProxy) {
        guard let selectedAssetID = model.selectedAssetID,
              assets.contains(where: { $0.id == selectedAssetID })
        else { return }

        withAnimation(.easeOut(duration: 0.16)) {
            scrollProxy.scrollTo(selectedAssetID, anchor: .center)
        }
    }

    private func selectionMarqueeGesture(in visibleAssets: [DesignAsset]) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named(gridCoordinateSpace))
            .onChanged { value in
                guard !isIgnoringMarqueeDrag else { return }

                if marqueeState == nil {
                    if assetID(at: value.startLocation, in: visibleAssets) != nil {
                        isIgnoringMarqueeDrag = true
                        return
                    }

                    let modifiers = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
                    marqueeState = AssetGridMarqueeState(
                        start: value.startLocation,
                        current: value.location,
                        baselineSelection: model.selectedAssetIDs,
                        isAdditive: modifiers.contains(.command)
                    )
                } else if var state = marqueeState {
                    state.current = value.location
                    marqueeState = state
                }

                updateSelectionFromMarquee(in: visibleAssets)
            }
            .onEnded { _ in
                marqueeState = nil
                isIgnoringMarqueeDrag = false
                isGridFocused = true
            }
    }

    private func emptyBackgroundTapGesture(in visibleAssets: [DesignAsset]) -> some Gesture {
        SpatialTapGesture(count: 1, coordinateSpace: .named(gridCoordinateSpace))
            .onEnded { value in
                isGridFocused = true
                guard marqueeState == nil,
                      assetID(at: value.location, in: visibleAssets) == nil
                else { return }
                model.clearSelection()
            }
    }

    private func updateSelectionFromMarquee(in visibleAssets: [DesignAsset]) {
        guard let marqueeState else { return }

        let hitAssetIDs = AssetGridMarqueeSelectionResolver.hitAssetIDs(
            selectionRect: marqueeState.rect,
            visibleAssets: visibleAssets,
            itemFrames: itemFrames
        )
        let selection = marqueeState.isAdditive
            ? marqueeState.baselineSelection.union(hitAssetIDs)
            : Set(hitAssetIDs)

        model.replaceSelection(with: selection, focusAssetID: hitAssetIDs.last)
    }

    private func assetID(at point: CGPoint, in visibleAssets: [DesignAsset]) -> String? {
        AssetGridMarqueeSelectionResolver.hitAssetID(
            at: point,
            visibleAssets: visibleAssets,
            itemFrames: itemFrames
        )
    }
}

private enum GridNavigationDirection {
    case left
    case right
    case up
    case down
}

private struct AssetGridMetrics {
    let horizontalPadding: CGFloat
    let headerVerticalPadding: CGFloat
    let refinementBottomPadding: CGFloat
    let gridPadding: CGFloat
    let gridSpacing: CGFloat
    let rowSpacing: CGFloat
    let itemMinWidth: CGFloat
    let itemMaxWidth: CGFloat
    let isCompact: Bool
}
