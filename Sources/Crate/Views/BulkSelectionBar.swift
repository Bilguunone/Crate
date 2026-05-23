//
//  BulkSelectionBar.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import SwiftUI

struct BulkSelectionBar: View {
    @Environment(AppModel.self) private var model
    @Binding var isTagSheetPresented: Bool

    var body: some View {
        HStack(spacing: 8) {
            Label("\(model.selectedAssetCount) selected", systemImage: "checkmark.circle.fill")
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(CrateTheme.accent)

            Divider()
                .frame(height: 18)

            Button {
                model.addSelectedToCart()
            } label: {
                Label("Cart", systemImage: "cart.badge.plus")
            }

            Button {
                model.setSelectedFavorite(!model.selectedAssetsAreAllFavorites)
            } label: {
                Label(model.selectedAssetsAreAllFavorites ? "Unfavorite" : "Favorite", systemImage: model.selectedAssetsAreAllFavorites ? "heart.slash" : "heart")
            }

            Button {
                isTagSheetPresented = true
            } label: {
                Label("Tag", systemImage: "tag")
            }

            Button {
                Task { await model.exportSelectedAssetsToFolder() }
            } label: {
                Label("Export", systemImage: "tray.and.arrow.up")
            }

            Button(role: .destructive) {
                model.requestRemoveSelectedAssets()
            } label: {
                Label("Remove", systemImage: "trash")
            }

            Spacer(minLength: 8)

            if model.selectedAssetCount < model.filteredAssets.count {
                Button {
                    model.selectAllFilteredAssets()
                } label: {
                    Label("All", systemImage: "checkmark.circle")
                }
            }

            Button {
                model.clearSelection()
            } label: {
                Label("Clear", systemImage: "xmark.circle")
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(CrateTheme.faintHairline)
        }
    }
}
