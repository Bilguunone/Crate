//
//  AssetStore+Fetching.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import Foundation

extension AssetStore {
    func fetchPacks() throws -> [AssetPack] {
        let rows = try database.query("SELECT * FROM packs ORDER BY imported_at DESC")
        return rows.map {
            AssetPack(
                id: $0["id"]?.string ?? "",
                displayName: $0["display_name"]?.string ?? "",
                source: $0["source"]?.string ?? "",
                importedAt: Date(timeIntervalSince1970: $0["imported_at"]?.double ?? 0),
                assetCount: $0["asset_count"]?.int ?? 0
            )
        }
    }

    func fetchAssets() throws -> [DesignAsset] {
        let assetRows = try database.query("SELECT * FROM assets ORDER BY display_name COLLATE NOCASE ASC")
        let variantRows = try database.query("SELECT * FROM asset_variants ORDER BY role ASC")
        let tagRows = try database.query("SELECT * FROM asset_tags")

        let variantsByAsset = Dictionary(grouping: variantRows.map(Self.variant(from:)), by: \.assetID)
        let tagsByAsset = Dictionary(grouping: tagRows.map(Self.tag(from:)), by: { row in row.assetID }).mapValues { rows in rows.map(\.tag) }

        return assetRows.map { row in
            let assetID = row["id"]?.string ?? ""
            let thumbnail = row["thumbnail_path"]?.string ?? ""
            return DesignAsset(
                id: assetID,
                packID: row["pack_id"]?.string ?? "",
                displayName: row["display_name"]?.string ?? "",
                normalizedName: row["normalized_name"]?.string ?? "",
                primaryVariantID: row["primary_variant_id"]?.string ?? "",
                kind: row["kind"]?.string ?? "",
                createdAt: Date(timeIntervalSince1970: row["created_at"]?.double ?? 0),
                variants: variantsByAsset[assetID] ?? [],
                tags: tagsByAsset[assetID] ?? [],
                thumbnailURL: thumbnail.isEmpty ? nil : URL(fileURLWithPath: thumbnail)
            )
        }
    }

    func fetchCart() throws -> [CartItem] {
        let rows = try database.query("SELECT * FROM cart_items ORDER BY added_at ASC")
        return rows.map {
            CartItem(
                id: $0["id"]?.string ?? "",
                assetID: $0["asset_id"]?.string ?? "",
                addedAt: Date(timeIntervalSince1970: $0["added_at"]?.double ?? 0),
                exportName: Self.optionalString($0["export_name"]),
                note: Self.optionalString($0["note"])
            )
        }
    }

    func fetchCollections() throws -> [AssetCollection] {
        let collectionRows = try database.query("SELECT * FROM collections ORDER BY created_at DESC")
        let itemRows = try database.query("SELECT * FROM collection_items ORDER BY order_index ASC")
        let itemsByCollection = Dictionary(grouping: itemRows, by: { $0["collection_id"]?.string ?? "" })

        return collectionRows.map { row in
            let id = row["id"]?.string ?? ""
            return AssetCollection(
                id: id,
                name: row["name"]?.string ?? "",
                coverAssetID: Self.optionalString(row["cover_asset_id"]),
                createdAt: Date(timeIntervalSince1970: row["created_at"]?.double ?? 0),
                assetIDs: (itemsByCollection[id] ?? []).map { $0["asset_id"]?.string ?? "" }
            )
        }
    }

    func fetchUsageAssetIDs(event: String? = nil) throws -> Set<String> {
        let rows: [[String: SQLiteValue]]
        if let event {
            rows = try database.query(
                "SELECT DISTINCT asset_id FROM usage_events WHERE event_type = ?",
                values: [.text(event)]
            )
        } else {
            rows = try database.query("SELECT DISTINCT asset_id FROM usage_events")
        }
        return Set(rows.map { $0["asset_id"]?.string ?? "" }.filter { !$0.isEmpty })
    }

    func fetchFavoriteAssetIDs() throws -> Set<String> {
        let rows = try database.query("SELECT asset_id FROM favorite_assets")
        return Set(rows.map { $0["asset_id"]?.string ?? "" }.filter { !$0.isEmpty })
    }

    func fetchUserTagFacets() throws -> [UserTagFacet] {
        let rows = try database.query(
            """
            SELECT namespace, value, COUNT(DISTINCT asset_id) AS count
            FROM asset_tags
            WHERE source = ? AND protected = 1
            GROUP BY namespace, value
            ORDER BY namespace COLLATE NOCASE ASC, value COLLATE NOCASE ASC
            """,
            values: [.text("user")]
        )

        return rows.map {
            UserTagFacet(
                namespace: $0["namespace"]?.string ?? "",
                value: $0["value"]?.string ?? "",
                count: $0["count"]?.int ?? 0
            )
        }
    }

    private static func variant(from row: [String: SQLiteValue]) -> AssetVariant {
        AssetVariant(
            id: row["id"]?.string ?? "",
            assetID: row["asset_id"]?.string ?? "",
            role: AssetVariantRole(rawValue: row["role"]?.string ?? "") ?? .original,
            fileURL: URL(fileURLWithPath: row["file_path"]?.string ?? ""),
            originalFileName: row["original_file_name"]?.string ?? "",
            fileExtension: row["file_extension"]?.string ?? "",
            width: row["width"]?.int ?? 0,
            height: row["height"]?.int ?? 0,
            hasAlpha: row["has_alpha"]?.bool ?? false,
            byteCount: row["byte_count"]?.int64 ?? 0
        )
    }

    private static func tag(from row: [String: SQLiteValue]) -> (assetID: String, tag: AssetTag) {
        (
            row["asset_id"]?.string ?? "",
            AssetTag(
                namespace: row["namespace"]?.string ?? "",
                value: row["value"]?.string ?? "",
                source: row["source"]?.string ?? "",
                confidence: row["confidence"]?.double ?? 1,
                protected: row["protected"]?.bool ?? false
            )
        )
    }

    private static func optionalString(_ value: SQLiteValue?) -> String? {
        guard let value, case .text(let string) = value, !string.isEmpty else { return nil }
        return string
    }
}
