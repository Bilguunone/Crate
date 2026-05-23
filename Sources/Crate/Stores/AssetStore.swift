//
//  AssetStore.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-22.
//

import Foundation

final class AssetStore {
    let database: SQLiteDatabase

    init(databaseURL: URL) throws {
        database = try SQLiteDatabase(url: databaseURL)
        try createSchema()
    }
}
