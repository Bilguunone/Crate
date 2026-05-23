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
    private let gridPadding: CGFloat = 20
    private let gridSpacing: CGFloat = 16
    private let rowSpacing: CGFloat = 14
    private let itemMinWidth: CGFloat = 154
    private let itemMaxWidth: CGFloat = 220

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let pack = model.selectedPack {
                    Button(role: .destructive) {
                        model.requestRemovePack(pack)
                    } label: {
                        Label("Remove Pack", systemImage: "trash")
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
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            refinementBar
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            Divider()

            if model.filteredAssets.isEmpty {
                AssetEmptyState(isLibraryEmpty: model.assets.isEmpty)
            } else {
                GeometryReader { proxy in
                    let visibleAssets = model.filteredAssets
                    let columnCount = gridColumnCount(for: proxy.size.width)

                    ScrollViewReader { scrollProxy in
                        ZStack(alignment: .topLeading) {
                            ScrollView {
                                LazyVGrid(columns: gridColumns(count: columnCount), spacing: rowSpacing) {
                                    ForEach(visibleAssets) { asset in
                                        AssetGridItemView(asset: asset) {
                                            isGridFocused = true
                                        }
                                        .id(asset.id)
                                        .assetGridItemFrame(id: asset.id, coordinateSpace: gridCoordinateSpace)
                                    }
                                }
                                .padding(gridPadding)
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
                RefinementMenu(title: "Kind", value: model.refinedKind?.capitalized ?? "Any", systemImage: "tag") {
                    Button("Any Kind") { model.setRefinedKind(nil) }
                    Divider()
                    ForEach(model.availableRefinementKinds, id: \.self) { kind in
                        Button(kind.capitalized) { model.setRefinedKind(kind) }
                    }
                }

                RefinementMenu(title: "Material", value: model.refinedMaterial?.capitalized ?? "Any", systemImage: "swatchpalette") {
                    Button("Any Material") { model.setRefinedMaterial(nil) }
                    Divider()
                    ForEach(model.availableRefinementMaterials, id: \.self) { material in
                        Button(material.capitalized) { model.setRefinedMaterial(material) }
                    }
                }

                RefinementMenu(title: "Use", value: refinedUseTitle, systemImage: "wand.and.stars") {
                    Button("Any Use") { model.setRefinedUse(nil) }
                    Divider()
                    ForEach(model.availableRefinementUses, id: \.self) { use in
                        Button(use.replacingOccurrences(of: "-", with: " ").capitalized) { model.setRefinedUse(use) }
                    }
                }

                RefinementMenu(title: "Alpha", value: model.refinedAlpha.title, systemImage: "checkerboard.rectangle") {
                    ForEach(AssetAlphaFilter.allCases) { filter in
                        Button(filter.title) { model.setRefinedAlpha(filter) }
                    }
                }

                RefinementMenu(title: "Sort", value: model.sortMode.title, systemImage: "arrow.up.arrow.down") {
                    ForEach(AssetSortMode.allCases) { mode in
                        Button(mode.title) { model.setSortMode(mode) }
                    }
                }

                if model.hasRefinements {
                    Button {
                        model.clearRefinements()
                    } label: {
                        Label("Clear", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Clear browsing refinements")
                }

                if !model.filteredAssets.isEmpty {
                    Button {
                        model.selectAllFilteredAssets()
                    } label: {
                        Label("Select All", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Select all visible assets")
                }
            }
            .padding(.vertical, 1)
        }
    }

    private var refinedUseTitle: String {
        guard let refinedUse = model.refinedUse else { return "Any" }
        return refinedUse.replacingOccurrences(of: "-", with: " ").capitalized
    }

    private func smartTitle(_ kind: SmartCollectionKind) -> String {
        if kind == .similarToSelected,
           let anchorID = model.smartSimilarAnchorID,
           let anchor = model.assetsByID[anchorID] {
            return "Similar to \(anchor.displayName)"
        }
        return kind.title
    }

    private func gridColumns(count: Int) -> [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: itemMinWidth, maximum: itemMaxWidth), spacing: gridSpacing),
            count: count
        )
    }

    private func gridColumnCount(for width: CGFloat) -> Int {
        let contentWidth = max(itemMinWidth, width - (gridPadding * 2))
        let maximumColumns = max(1, Int((contentWidth + gridSpacing) / (itemMinWidth + gridSpacing)))
        let minimumColumns = max(1, Int(ceil((contentWidth + gridSpacing) / (itemMaxWidth + gridSpacing))))
        return max(1, max(minimumColumns, maximumColumns))
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
