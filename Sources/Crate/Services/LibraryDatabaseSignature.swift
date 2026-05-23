//
//  LibraryDatabaseSignature.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import Foundation

struct LibraryDatabaseSignature: Equatable, Sendable {
    private let files: [FileSignature]

    init(paths: LibraryPaths, fileManager: FileManager = .default) {
        files = [
            paths.databaseURL,
            URL(fileURLWithPath: paths.databaseURL.path + "-wal"),
            URL(fileURLWithPath: paths.databaseURL.path + "-shm")
        ].map { FileSignature(url: $0, fileManager: fileManager) }
    }
}

private struct FileSignature: Equatable, Sendable {
    let path: String
    let exists: Bool
    let size: UInt64
    let modifiedAt: TimeInterval

    init(url: URL, fileManager: FileManager) {
        path = url.standardizedFileURL.path
        guard let attributes = try? fileManager.attributesOfItem(atPath: path) else {
            exists = false
            size = 0
            modifiedAt = 0
            return
        }

        exists = true
        size = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
        modifiedAt = (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
    }
}
