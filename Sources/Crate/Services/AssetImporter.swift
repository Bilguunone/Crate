//
//  AssetImporter.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-22.
//

import Foundation

final class AssetImporter {
    let paths: LibraryPaths
    let fileManager = FileManager.default

    init(paths: LibraryPaths) {
        self.paths = paths
    }
}
