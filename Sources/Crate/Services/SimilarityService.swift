//
//  SimilarityService.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-22.
//

import Foundation

enum SimilarityService {
    static func similarAssets(to asset: DesignAsset, in assets: [DesignAsset], limit: Int = 12) -> [DesignAsset] {
        assets
            .filter { $0.id != asset.id }
            .map { candidate in
                (candidate, score(asset, candidate))
            }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map(\.0)
    }

    private static func score(_ lhs: DesignAsset, _ rhs: DesignAsset) -> Double {
        var value = 0.0
        if lhs.packID == rhs.packID { value += 2.0 }
        if lhs.kind == rhs.kind { value += 3.0 }
        value += Double(lhs.tagValues.intersection(rhs.tagValues).count)

        if let left = lhs.primaryVariant, let right = rhs.primaryVariant {
            let leftRatio = Double(left.width) / Double(max(left.height, 1))
            let rightRatio = Double(right.width) / Double(max(right.height, 1))
            let ratioDelta = abs(leftRatio - rightRatio)
            if ratioDelta < 0.1 { value += 1.25 }
            if left.hasAlpha == right.hasAlpha { value += 0.75 }
        }

        return value
    }
}
