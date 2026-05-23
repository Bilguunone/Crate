//
//  AssetStore+Schema.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import Foundation

extension AssetStore {
    func createSchema() throws {
        try database.execute("""
        CREATE TABLE IF NOT EXISTS packs (
            id TEXT PRIMARY KEY,
            display_name TEXT NOT NULL,
            source TEXT NOT NULL,
            imported_at REAL NOT NULL,
            asset_count INTEGER NOT NULL
        )
        """)

        try database.execute("""
        CREATE TABLE IF NOT EXISTS assets (
            id TEXT PRIMARY KEY,
            pack_id TEXT NOT NULL REFERENCES packs(id) ON DELETE CASCADE,
            display_name TEXT NOT NULL,
            normalized_name TEXT NOT NULL,
            primary_variant_id TEXT NOT NULL,
            kind TEXT NOT NULL,
            created_at REAL NOT NULL,
            thumbnail_path TEXT
        )
        """)

        try database.execute("""
        CREATE TABLE IF NOT EXISTS asset_variants (
            id TEXT PRIMARY KEY,
            asset_id TEXT NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
            role TEXT NOT NULL,
            file_path TEXT NOT NULL,
            original_file_name TEXT NOT NULL,
            file_extension TEXT NOT NULL,
            width INTEGER NOT NULL,
            height INTEGER NOT NULL,
            has_alpha INTEGER NOT NULL,
            byte_count INTEGER NOT NULL
        )
        """)

        try database.execute("""
        CREATE TABLE IF NOT EXISTS tags (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            namespace TEXT NOT NULL,
            value TEXT NOT NULL,
            UNIQUE(namespace, value)
        )
        """)

        try database.execute("""
        CREATE TABLE IF NOT EXISTS asset_tags (
            asset_id TEXT NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
            namespace TEXT NOT NULL,
            value TEXT NOT NULL,
            source TEXT NOT NULL,
            confidence REAL NOT NULL,
            protected INTEGER NOT NULL,
            PRIMARY KEY(asset_id, namespace, value, source)
        )
        """)

        try database.execute("""
        CREATE TABLE IF NOT EXISTS favorite_assets (
            asset_id TEXT PRIMARY KEY REFERENCES assets(id) ON DELETE CASCADE,
            created_at REAL NOT NULL
        )
        """)

        try database.execute("""
        CREATE TABLE IF NOT EXISTS collections (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            cover_asset_id TEXT,
            created_at REAL NOT NULL
        )
        """)

        try database.execute("""
        CREATE TABLE IF NOT EXISTS collection_items (
            collection_id TEXT NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
            asset_id TEXT NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
            order_index INTEGER NOT NULL,
            PRIMARY KEY(collection_id, asset_id)
        )
        """)

        try database.execute("""
        CREATE TABLE IF NOT EXISTS cart_items (
            id TEXT PRIMARY KEY,
            asset_id TEXT NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
            added_at REAL NOT NULL,
            export_name TEXT,
            note TEXT
        )
        """)

        try database.execute("""
        CREATE TABLE IF NOT EXISTS usage_events (
            id TEXT PRIMARY KEY,
            asset_id TEXT NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
            event_type TEXT NOT NULL,
            created_at REAL NOT NULL
        )
        """)
    }
}
