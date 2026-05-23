//
//  AssetStore+Writes.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import Foundation

extension AssetStore {
    func replacePack(_ pack: AssetPack, assets: [DesignAsset]) throws {
        try database.transaction {
            try database.execute("DELETE FROM packs WHERE id = ?", values: [.text(pack.id)])
            try insert(pack)
            for asset in assets {
                try insert(asset)
            }
        }
    }

    func deletePack(id: String) throws {
        try database.transaction {
            try database.execute(
                "UPDATE collections SET cover_asset_id = NULL WHERE cover_asset_id IN (SELECT id FROM assets WHERE pack_id = ?)",
                values: [.text(id)]
            )
            try database.execute("DELETE FROM packs WHERE id = ?", values: [.text(id)])
            try database.execute("DELETE FROM collections WHERE id NOT IN (SELECT DISTINCT collection_id FROM collection_items)")
        }
    }

    func deleteAssets(ids: Set<String>) throws {
        guard !ids.isEmpty else { return }

        let values = ids.sorted().map(SQLiteValue.text)
        let placeholders = Array(repeating: "?", count: values.count).joined(separator: ", ")

        try database.transaction {
            let packRows = try database.query(
                "SELECT DISTINCT pack_id FROM assets WHERE id IN (\(placeholders))",
                values: values
            )
            let packIDs = packRows.map { $0["pack_id"]?.string ?? "" }.filter { !$0.isEmpty }

            try database.execute(
                "UPDATE collections SET cover_asset_id = NULL WHERE cover_asset_id IN (\(placeholders))",
                values: values
            )
            try database.execute(
                "DELETE FROM assets WHERE id IN (\(placeholders))",
                values: values
            )

            for packID in packIDs {
                let count = try database.query(
                    "SELECT COUNT(*) AS count FROM assets WHERE pack_id = ?",
                    values: [.text(packID)]
                ).first?["count"]?.int ?? 0

                if count == 0 {
                    try database.execute("DELETE FROM packs WHERE id = ?", values: [.text(packID)])
                } else {
                    try database.execute(
                        "UPDATE packs SET asset_count = ? WHERE id = ?",
                        values: [.int(Int64(count)), .text(packID)]
                    )
                }
            }

            try database.execute("DELETE FROM collections WHERE id NOT IN (SELECT DISTINCT collection_id FROM collection_items)")
            try database.execute(
                """
                DELETE FROM tags
                WHERE NOT EXISTS (
                  SELECT 1 FROM asset_tags
                  WHERE asset_tags.namespace = tags.namespace
                    AND asset_tags.value = tags.value
                )
                """
            )
        }
    }

    func saveCart(_ items: [CartItem]) throws {
        try database.transaction {
            try database.execute("DELETE FROM cart_items")
            for item in items {
                try database.execute(
                    """
                    INSERT INTO cart_items(id, asset_id, added_at, export_name, note)
                    VALUES (?, ?, ?, ?, ?)
                    """,
                    values: [
                        .text(item.id),
                        .text(item.assetID),
                        .double(item.addedAt.timeIntervalSince1970),
                        item.exportName.map(SQLiteValue.text) ?? .null,
                        item.note.map(SQLiteValue.text) ?? .null
                    ]
                )
            }
        }
    }

    func saveCollection(_ collection: AssetCollection) throws {
        try database.transaction {
            try database.execute(
                """
                INSERT OR REPLACE INTO collections(id, name, cover_asset_id, created_at)
                VALUES (?, ?, ?, ?)
                """,
                values: [
                    .text(collection.id),
                    .text(collection.name),
                    collection.coverAssetID.map(SQLiteValue.text) ?? .null,
                    .double(collection.createdAt.timeIntervalSince1970)
                ]
            )
            try database.execute("DELETE FROM collection_items WHERE collection_id = ?", values: [.text(collection.id)])
            for (index, assetID) in collection.assetIDs.enumerated() {
                try database.execute(
                    "INSERT INTO collection_items(collection_id, asset_id, order_index) VALUES (?, ?, ?)",
                    values: [.text(collection.id), .text(assetID), .int(Int64(index))]
                )
            }
        }
    }

    func recordUsage(assetID: String, event: String) throws {
        try database.execute(
            "INSERT INTO usage_events(id, asset_id, event_type, created_at) VALUES (?, ?, ?, ?)",
            values: [.text(UUID().uuidString), .text(assetID), .text(event), .double(Date().timeIntervalSince1970)]
        )
    }

    func setFavorite(assetID: String, isFavorite: Bool) throws {
        if isFavorite {
            try database.execute(
                """
                INSERT OR REPLACE INTO favorite_assets(asset_id, created_at)
                VALUES (?, ?)
                """,
                values: [.text(assetID), .double(Date().timeIntervalSince1970)]
            )
        } else {
            try database.execute(
                "DELETE FROM favorite_assets WHERE asset_id = ?",
                values: [.text(assetID)]
            )
        }
    }

    func saveUserTag(assetID: String, namespace: String, value: String) throws {
        try database.transaction {
            try database.execute(
                "INSERT OR IGNORE INTO tags(namespace, value) VALUES (?, ?)",
                values: [.text(namespace), .text(value)]
            )
            try database.execute(
                """
                INSERT OR REPLACE INTO asset_tags(asset_id, namespace, value, source, confidence, protected)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                values: [
                    .text(assetID),
                    .text(namespace),
                    .text(value),
                    .text("user"),
                    .double(1),
                    .int(1)
                ]
            )
        }
    }

    func deleteUserTag(assetID: String, namespace: String, value: String) throws {
        try database.transaction {
            try database.execute(
                "DELETE FROM asset_tags WHERE asset_id = ? AND namespace = ? AND value = ? AND source = ? AND protected = 1",
                values: [.text(assetID), .text(namespace), .text(value), .text("user")]
            )
            try database.execute(
                """
                DELETE FROM tags
                WHERE namespace = ? AND value = ?
                  AND NOT EXISTS (
                    SELECT 1 FROM asset_tags
                    WHERE asset_tags.namespace = tags.namespace
                      AND asset_tags.value = tags.value
                  )
                """,
                values: [.text(namespace), .text(value)]
            )
        }
    }

    func replaceComputedTags(_ updates: [String: [AssetTag]]) throws {
        try database.transaction {
            for (assetID, tags) in updates {
                try database.execute(
                    "DELETE FROM asset_tags WHERE asset_id = ? AND source = ? AND protected = 0",
                    values: [.text(assetID), .text("computed")]
                )

                for tag in tags {
                    try database.execute(
                        "INSERT OR IGNORE INTO tags(namespace, value) VALUES (?, ?)",
                        values: [.text(tag.namespace), .text(tag.value)]
                    )
                    try database.execute(
                        """
                        INSERT OR REPLACE INTO asset_tags(asset_id, namespace, value, source, confidence, protected)
                        VALUES (?, ?, ?, ?, ?, ?)
                        """,
                        values: [
                            .text(assetID),
                            .text(tag.namespace),
                            .text(tag.value),
                            .text(tag.source),
                            .double(tag.confidence),
                            .int(tag.protected ? 1 : 0)
                        ]
                    )
                }
            }
        }
    }

    func replaceThumbnailPaths(_ updates: [String: URL?]) throws {
        try database.transaction {
            for (assetID, url) in updates {
                try database.execute(
                    "UPDATE assets SET thumbnail_path = ? WHERE id = ?",
                    values: [
                        url.map { .text($0.path) } ?? .null,
                        .text(assetID)
                    ]
                )
            }
        }
    }

    func rewriteStoredPaths(from oldRoot: URL, to newRoot: URL) throws {
        let oldPath = oldRoot.standardizedFileURL.path
        let newPath = newRoot.standardizedFileURL.path

        try database.transaction {
            let assetRows = try database.query("SELECT id, thumbnail_path FROM assets WHERE thumbnail_path IS NOT NULL AND thumbnail_path != ''")
            for row in assetRows {
                let id = row["id"]?.string ?? ""
                let path = row["thumbnail_path"]?.string ?? ""
                let rewritten = Self.rewrite(path: path, from: oldPath, to: newPath)
                guard !id.isEmpty, rewritten != path else { continue }
                try database.execute(
                    "UPDATE assets SET thumbnail_path = ? WHERE id = ?",
                    values: [.text(rewritten), .text(id)]
                )
            }

            let variantRows = try database.query("SELECT id, file_path FROM asset_variants")
            for row in variantRows {
                let id = row["id"]?.string ?? ""
                let path = row["file_path"]?.string ?? ""
                let rewritten = Self.rewrite(path: path, from: oldPath, to: newPath)
                guard !id.isEmpty, rewritten != path else { continue }
                try database.execute(
                    "UPDATE asset_variants SET file_path = ? WHERE id = ?",
                    values: [.text(rewritten), .text(id)]
                )
            }
        }
    }

    private func insert(_ pack: AssetPack) throws {
        try database.execute(
            """
            INSERT INTO packs(id, display_name, source, imported_at, asset_count)
            VALUES (?, ?, ?, ?, ?)
            """,
            values: [
                .text(pack.id),
                .text(pack.displayName),
                .text(pack.source),
                .double(pack.importedAt.timeIntervalSince1970),
                .int(Int64(pack.assetCount))
            ]
        )
    }

    private func insert(_ asset: DesignAsset) throws {
        try database.execute(
            """
            INSERT INTO assets(id, pack_id, display_name, normalized_name, primary_variant_id, kind, created_at, thumbnail_path)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            values: [
                .text(asset.id),
                .text(asset.packID),
                .text(asset.displayName),
                .text(asset.normalizedName),
                .text(asset.primaryVariantID),
                .text(asset.kind),
                .double(asset.createdAt.timeIntervalSince1970),
                asset.thumbnailURL.map { .text($0.path) } ?? .null
            ]
        )

        for variant in asset.variants {
            try database.execute(
                """
                INSERT INTO asset_variants(id, asset_id, role, file_path, original_file_name, file_extension, width, height, has_alpha, byte_count)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                values: [
                    .text(variant.id),
                    .text(variant.assetID),
                    .text(variant.role.rawValue),
                    .text(variant.fileURL.path),
                    .text(variant.originalFileName),
                    .text(variant.fileExtension),
                    .int(Int64(variant.width)),
                    .int(Int64(variant.height)),
                    .int(variant.hasAlpha ? 1 : 0),
                    .int(variant.byteCount)
                ]
            )
        }

        for tag in asset.tags {
            try database.execute(
                "INSERT OR IGNORE INTO tags(namespace, value) VALUES (?, ?)",
                values: [.text(tag.namespace), .text(tag.value)]
            )
            try database.execute(
                """
                INSERT OR REPLACE INTO asset_tags(asset_id, namespace, value, source, confidence, protected)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                values: [
                    .text(asset.id),
                    .text(tag.namespace),
                    .text(tag.value),
                    .text(tag.source),
                    .double(tag.confidence),
                    .int(tag.protected ? 1 : 0)
                ]
            )
        }
    }

    private static func rewrite(path: String, from oldRoot: String, to newRoot: String) -> String {
        if path == oldRoot {
            return newRoot
        }
        let prefix = oldRoot + "/"
        if path.hasPrefix(prefix) {
            return newRoot + String(path.dropFirst(oldRoot.count))
        }

        for marker in ["/10_Library/", "/_thumbnails/"] {
            guard let range = path.range(of: marker) else { continue }
            return newRoot + String(path[range.lowerBound...])
        }

        return path
    }
}
