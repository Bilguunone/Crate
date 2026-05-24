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
        GeometryReader { proxy in
            let isCompact = proxy.size.width < 720
            let maxBarWidth = max(280, min(proxy.size.width - 28, 980))

            filledBar(isCompact: isCompact)
                .frame(maxWidth: maxBarWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(height: CartTrayMetrics.hostHeight)
    }

    private func filledBar(isCompact: Bool) -> some View {
        VStack(spacing: CartTrayMetrics.rowSpacing) {
            cartHeader

            if isCompact {
                compactContent
            } else {
                regularContent
            }
        }
        .padding(.horizontal, isCompact ? 12 : 16)
        .padding(.vertical, CartTrayMetrics.verticalPadding)
        .frame(height: CartTrayMetrics.barHeight)
        .crateGlassPanel(cornerRadius: CartTrayMetrics.barCornerRadius, interactive: true, variant: .regular)
    }

    private var regularContent: some View {
        HStack(spacing: 10) {
            cartThumbScroll
        }
    }

    private var compactContent: some View {
        HStack(spacing: 10) {
            cartThumbScroll
        }
    }

    private var cartHeader: some View {
        HStack(spacing: 8) {
            Label("Cart", systemImage: "cart")
                .font(.caption)
                .fontWeight(.semibold)

            Spacer(minLength: 12)

            Text("\(model.cartItems.count) selected")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .monospacedDigit()

            cartActionsMenu
        }
        .frame(maxWidth: .infinity)
    }

    private var cartThumbScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if model.cartAssets.isEmpty {
                    Text("Add assets here for export.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    ForEach(model.cartAssets) { asset in
                        CartThumb(asset: asset)
                            .transition(.cartItemPuff)
                    }
                }
            }
            .animation(.snappy(duration: 0.26, extraBounce: 0.14), value: model.cartAssets.map(\.id))
        }
        .frame(height: CartTrayMetrics.itemHeight)
    }

    private var cartActionsMenu: some View {
        Menu {
            Button {
                model.saveCartAsCollection()
            } label: {
                Label("Save as Collection", systemImage: "rectangle.stack.badge.plus")
            }
            .disabled(model.cartItems.isEmpty)

            if model.hasOpenPixelmatorProject {
                Button {
                    model.sendCartToOpenPixelmatorProject()
                } label: {
                    Label("Add to \(model.pixelmatorOpenProjectTitle)", systemImage: "photo.badge.plus")
                }
                .disabled(model.pixelmatorFrontDocumentURL == nil || model.isSendingToPixelmator)
            }

            Button {
                model.sendCartToChosenPixelmatorDocument()
            } label: {
                Label("Choose Pixelmator Document...", systemImage: "doc.badge.plus")
            }
            .disabled(model.isSendingToPixelmator)

            Divider()

            Button {
                Task { await model.exportCartToFolder() }
            } label: {
                Label("Export Folder", systemImage: "folder.badge.plus")
            }

            Button {
                Task { await model.exportCartToZip() }
            } label: {
                Label("Export Zip", systemImage: "doc.zipper")
            }

            Divider()

            Button(role: .destructive) {
                withAnimation(.snappy(duration: 0.24, extraBounce: 0.10)) {
                    model.clearCart()
                }
            } label: {
                Label("Clear Cart", systemImage: "trash")
            }
        } label: {
            Label("Cart Actions", systemImage: "ellipsis.circle")
                .labelStyle(.iconOnly)
        }
        .menuStyle(.button)
        .disabled(model.cartItems.isEmpty)
        .controlSize(.small)
        .help("Cart actions")
    }
}

private struct CartThumb: View {
    @Environment(AppModel.self) private var model
    @State private var isHovering = false
    let asset: DesignAsset

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                model.select(asset)
            } label: {
                CratePreviewSurface(cornerRadius: CartTrayMetrics.thumbnailCornerRadius) {
                    ThumbnailImage(url: asset.thumbnailURL ?? asset.primaryVariant?.fileURL)
                }
                .frame(width: CartTrayMetrics.thumbnailSize, height: CartTrayMetrics.thumbnailSize)
            }
            .buttonStyle(.plain)
            .contentShape(.rect(cornerRadius: CartTrayMetrics.thumbnailCornerRadius))

            Button {
                withAnimation(.snappy(duration: 0.22, extraBounce: 0.10)) {
                    model.removeFromCart(asset.id)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: CartTrayMetrics.removeButtonSize, height: CartTrayMetrics.removeButtonSize)
                    .background(.regularMaterial, in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.34), lineWidth: 0.8)
                    }
                    .shadow(color: .black.opacity(0.28), radius: 5, y: 2)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .contentShape(Circle())
            .opacity(isHovering ? 1 : 0.82)
            .scaleEffect(isHovering ? 1.04 : 1)
            .offset(x: 8, y: -8)
            .help("Remove from cart")
        }
        .frame(
            width: CartTrayMetrics.itemWidth,
            height: CartTrayMetrics.itemHeight,
            alignment: .center
        )
        .padding(.top, CartTrayMetrics.removeButtonOverhang)
        .onHover { isHovering = $0 }
        .animation(.snappy(duration: 0.16, extraBounce: 0.06), value: isHovering)
        .contextMenu {
            Button(role: .destructive) {
                withAnimation(.snappy(duration: 0.22, extraBounce: 0.10)) {
                    model.removeFromCart(asset.id)
                }
            } label: {
                Label("Remove from Cart", systemImage: "trash")
            }
        }
        .help(asset.displayName)
    }
}

private enum CartTrayMetrics {
    static let hostHeight: CGFloat = 146
    static let barHeight: CGFloat = 132
    static let thumbnailSize: CGFloat = 72
    static let itemWidth: CGFloat = 84
    static let itemHeight: CGFloat = 84
    static let thumbnailCornerRadius: CGFloat = 12
    static let removeButtonSize: CGFloat = 24
    static let removeButtonOverhang: CGFloat = 4
    static let verticalPadding: CGFloat = 12
    static let rowSpacing: CGFloat = 6
    static let verticalInset = verticalPadding
    static let barCornerRadius = thumbnailCornerRadius + verticalInset
}

private struct CartItemPuffModifier: ViewModifier {
    let scale: CGFloat
    let opacity: Double
    let blurRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .blur(radius: blurRadius)
    }
}

private extension AnyTransition {
    static var cartItemPuff: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: CartItemPuffModifier(scale: 0.72, opacity: 0, blurRadius: 5),
                identity: CartItemPuffModifier(scale: 1, opacity: 1, blurRadius: 0)
            ),
            removal: .modifier(
                active: CartItemPuffModifier(scale: 1.22, opacity: 0, blurRadius: 7),
                identity: CartItemPuffModifier(scale: 1, opacity: 1, blurRadius: 0)
            )
        )
    }
}
