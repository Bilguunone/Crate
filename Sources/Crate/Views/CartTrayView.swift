//
//  CartTrayView.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-22.
//

import SwiftUI

struct CartTrayView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            if model.cartItems.isEmpty {
                emptyBar
            } else {
                filledBar
            }
        }
    }

    private var emptyBar: some View {
        HStack(spacing: 8) {
            Label("Cart empty", systemImage: "cart")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Text("Selected assets appear here for export.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(.bar)
    }

    private var filledBar: some View {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Cart", systemImage: "cart")
                        .font(.headline)
                    Text("\(model.cartItems.count) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 92, alignment: .leading)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if model.cartAssets.isEmpty {
                            Text("Add assets here for export.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(model.cartAssets) { asset in
                                CartThumb(asset: asset)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                Spacer(minLength: 8)

                Button {
                    model.saveCartAsCollection()
                } label: {
                    Label("Save", systemImage: "rectangle.stack.badge.plus")
                }
                .disabled(model.cartItems.isEmpty)

                Menu {
                    Button {
                        Task { await model.exportCartToFolder() }
                    } label: {
                        Label("Folder", systemImage: "folder.badge.plus")
                    }

                    Button {
                        Task { await model.exportCartToZip() }
                    } label: {
                        Label("Zip", systemImage: "doc.zipper")
                    }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(model.cartItems.isEmpty)

                Button {
                    model.clearCart()
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(model.cartItems.isEmpty)
                .help("Clear cart")
            }
            .padding(.horizontal, 16)
            .frame(height: 78)
            .background(.bar)
    }
}

private struct CartThumb: View {
    @Environment(AppModel.self) private var model
    let asset: DesignAsset

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                model.select(asset)
            } label: {
                CratePreviewSurface(cornerRadius: 8) {
                    ThumbnailImage(url: asset.thumbnailURL ?? asset.primaryVariant?.fileURL)
                }
                .frame(width: 54, height: 54)
            }
            .buttonStyle(.plain)

            Button {
                model.removeFromCart(asset.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .offset(x: 5, y: -5)
        }
        .help(asset.displayName)
    }
}
