//
//  DuplicateModels.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import Foundation

struct DuplicateReport: Codable, Hashable, Sendable {
    var scannedAt: Date
    var scannedVariantCount: Int
    var exactFileGroups: [DuplicateCluster]
    var sameImageGroups: [DuplicateCluster]
    var jpgPngVariantGroups: [DuplicateCluster]
    var nearDuplicateGroups: [DuplicateCluster]

    static let empty = DuplicateReport(
        scannedAt: Date(timeIntervalSince1970: 0),
        scannedVariantCount: 0,
        exactFileGroups: [],
        sameImageGroups: [],
        jpgPngVariantGroups: [],
        nearDuplicateGroups: []
    )

    var candidateAssetIDs: Set<String> {
        Set((exactFileGroups + sameImageGroups + nearDuplicateGroups).flatMap(\.assetIDs))
    }

    var variantAssetIDs: Set<String> {
        Set(jpgPngVariantGroups.flatMap(\.assetIDs))
    }

    var totalIssueCount: Int {
        exactFileGroups.count + sameImageGroups.count + nearDuplicateGroups.count
    }

    var totalFindingCount: Int {
        totalIssueCount + jpgPngVariantGroups.count
    }
}

struct DuplicateCluster: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let reason: DuplicateReason
    let assetIDs: [String]
    let variantIDs: [String]
    let distance: Int?
}

enum DuplicateReason: String, Codable, Hashable, Sendable {
    case exactFile
    case sameImage
    case jpgPngVariant
    case nearDuplicate
}
