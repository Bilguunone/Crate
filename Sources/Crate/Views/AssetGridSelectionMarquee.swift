//
//  AssetGridSelectionMarquee.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import SwiftUI

struct AssetGridMarqueeState {
    let start: CGPoint
    var current: CGPoint
    let baselineSelection: Set<String>
    let isAdditive: Bool

    var rect: CGRect {
        CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
    }
}

struct AssetGridSelectionMarquee: View {
    let rect: CGRect

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(CrateTheme.accent.opacity(0.14))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(CrateTheme.accent.opacity(0.92), lineWidth: 1.5)
            }
            .frame(width: max(0, rect.width), height: max(0, rect.height))
            .offset(x: rect.minX, y: rect.minY)
            .shadow(color: CrateTheme.accent.opacity(0.12), radius: 8, y: 2)
            .allowsHitTesting(false)
    }
}

enum AssetGridMarqueeSelectionResolver {
    static func hitAssetIDs(
        selectionRect: CGRect,
        visibleAssets: [DesignAsset],
        itemFrames: [String: CGRect]
    ) -> [String] {
        visibleAssets.compactMap { asset in
            guard let frame = itemFrames[asset.id],
                  frame.intersects(selectionRect)
            else { return nil }
            return asset.id
        }
    }

    static func hitAssetID(
        at point: CGPoint,
        visibleAssets: [DesignAsset],
        itemFrames: [String: CGRect]
    ) -> String? {
        visibleAssets.first { asset in
            itemFrames[asset.id]?.contains(point) == true
        }?.id
    }
}

struct AssetGridItemFramePreferenceKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

extension View {
    func assetGridItemFrame(id: String, coordinateSpace: String) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: AssetGridItemFramePreferenceKey.self,
                    value: [id: proxy.frame(in: .named(coordinateSpace))]
                )
            }
        }
    }
}
