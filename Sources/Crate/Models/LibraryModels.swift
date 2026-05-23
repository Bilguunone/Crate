//
//  LibraryModels.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import Foundation

struct LibraryValidationReport: Codable, Hashable, Sendable {
    var root: URL
    var databaseExists: Bool
    var missingDirectories: [String]
    var packCount: Int
    var assetCount: Int
    var variantCount: Int
    var missingVariantFileCount: Int
    var missingThumbnailCount: Int
    var missingManifestCount: Int

    var isUsable: Bool {
        databaseExists && missingDirectories.isEmpty && missingVariantFileCount == 0
    }

    var issueCount: Int {
        missingDirectories.count
            + (databaseExists ? 0 : 1)
            + missingVariantFileCount
            + missingThumbnailCount
            + missingManifestCount
    }

    var summary: String {
        if isUsable && issueCount == 0 {
            return "Library is healthy: \(assetCount) assets, \(variantCount) files."
        }
        if isUsable {
            return "Library is usable with \(issueCount) warning\(issueCount == 1 ? "" : "s")."
        }
        return "Library needs attention: \(issueCount) issue\(issueCount == 1 ? "" : "s")."
    }
}

struct LibraryMigrationPlan: Codable, Hashable, Sendable {
    let sourceRoot: URL
    let destinationRoot: URL
}

struct LibraryMigrationResult: Sendable {
    let sourceRoot: URL
    let destinationRoot: URL
    let validationReport: LibraryValidationReport
    let removedSource: Bool
}
