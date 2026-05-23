//
//  BulkSelectionInspectorView.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import SwiftUI

struct BulkSelectionInspectorView: View {
    @Environment(AppModel.self) private var model
    @State private var isTagSheetPresented = false
    @State private var visibleSelectionSignature = ""

    private var selectionSignature: String {
        model.selectedAssetIDs.sorted().joined(separator: "|")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("\(model.selectedAssetCount) Selected", systemImage: "checkmark.circle.fill")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(CrateTheme.accent)

                    Text(selectionSummary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                InspectorSection(title: "Bulk Actions") {
                    Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                        GridRow {
                            actionButton("Cart", "cart.badge.plus") { model.addSelectedToCart() }
                            actionButton(model.selectedAssetsAreAllFavorites ? "Unfavorite" : "Favorite", model.selectedAssetsAreAllFavorites ? "heart.slash" : "heart") {
                                model.setSelectedFavorite(!model.selectedAssetsAreAllFavorites)
                            }
                        }
                        GridRow {
                            actionButton("Tag", "tag") { isTagSheetPresented = true }
                            actionButton("Export", "tray.and.arrow.up") {
                                Task { await model.exportSelectedAssetsToFolder() }
                            }
                        }
                        GridRow {
                            PixelmatorActionControl(scope: .selection, compact: true)
                                .gridCellColumns(2)
                        }
                        GridRow {
                            actionButton("Clear", "xmark.circle") { model.clearSelection() }
                            Button(role: .destructive) {
                                model.requestRemoveSelectedAssets()
                            } label: {
                                Label("Remove", systemImage: "trash")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }

                InspectorSection(title: "Selected Assets") {
                    if visibleSelectionSignature == selectionSignature {
                        VStack(spacing: 6) {
                            ForEach(model.selectedAssets.prefix(16)) { asset in
                                Button {
                                    model.select(asset)
                                } label: {
                                    SimilarAssetRow(asset: asset)
                                }
                                .buttonStyle(.plain)
                            }
                            if model.selectedAssetCount > 16 {
                                Text("+ \(model.selectedAssetCount - 16) more")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        InspectorDeferredSectionPlaceholder()
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .task(id: selectionSignature) {
                visibleSelectionSignature = ""
                try? await Task.sleep(nanoseconds: 120_000_000)
                guard !Task.isCancelled else { return }
                visibleSelectionSignature = selectionSignature
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $isTagSheetPresented) {
            BulkTagSheet()
        }
    }

    private var selectionSummary: String {
        let kinds = Set(model.selectedAssets.map(\.kind))
        if kinds.count == 1, let kind = kinds.first {
            return kind.capitalized
        }
        return "\(kinds.count) kinds"
    }

    private func actionButton(_ title: String, _ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

}
