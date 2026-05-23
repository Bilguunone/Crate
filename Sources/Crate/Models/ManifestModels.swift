//
//  ManifestModels.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-22.
//

import Foundation

struct PackManifest: Codable {
    var schemaVersion: Int
    var packID: String
    var displayName: String
    var source: String
    var importedAt: Date
    var importerVersion: String
    var assetCount: Int
    var rules: [String: String]
    var assets: [ManifestAsset]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case packID = "pack_id"
        case displayName = "display_name"
        case source
        case importedAt = "imported_at"
        case importerVersion = "importer_version"
        case assetCount = "asset_count"
        case rules
        case assets
    }
}

struct ManifestAsset: Codable {
    var id: String
    var displayName: String
    var originalFiles: [String]
    var variants: [String: String]
    var tags: [String: [String]]

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case originalFiles = "original_files"
        case variants
        case tags
    }
}
