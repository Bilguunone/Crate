//
//  LibraryManager.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-22.
//

import Foundation

struct LibraryPaths {
    let root: URL

    var inbox: URL { root.appendingPathComponent("00_Inbox", isDirectory: true) }
    var library: URL { root.appendingPathComponent("10_Library", isDirectory: true) }
    var packs: URL { library.appendingPathComponent("packs", isDirectory: true) }
    var collections: URL { root.appendingPathComponent("20_Collections", isDirectory: true) }
    var exports: URL { root.appendingPathComponent("30_Exports", isDirectory: true) }
    var databaseDirectory: URL { root.appendingPathComponent("_database", isDirectory: true) }
    var thumbnails: URL { root.appendingPathComponent("_thumbnails", isDirectory: true) }
    var manifests: URL { root.appendingPathComponent("_manifests", isDirectory: true) }
    var databaseURL: URL { databaseDirectory.appendingPathComponent("crate.sqlite") }

    func packLibraryURL(_ packID: String) -> URL {
        packs.appendingPathComponent(packID, isDirectory: true)
    }

    func packManifestURL(_ packID: String) -> URL {
        manifests.appendingPathComponent("\(packID).manifest.json")
    }
}

enum LibraryManager {
    static let userDefaultsKey = "Crate.LibraryRoot"

    static var suggestedRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("DesignAssets", isDirectory: true)
    }

    static func savedRoot() -> URL? {
        guard let value = UserDefaults.standard.string(forKey: userDefaultsKey), !value.isEmpty else { return nil }
        return URL(fileURLWithPath: value, isDirectory: true)
    }

    static func clearSavedRoot() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }

    static func directoryExists(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    static func missingLibraryMessage(for root: URL) -> String {
        if let volumeName = missingVolumeName(for: root) {
            return "External drive “\(volumeName)” is not mounted. Reconnect it, then choose the library again."
        }
        return "Saved library is missing: \(root.path)"
    }

    static func saveRoot(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: userDefaultsKey)
    }

    static func prepareLibrary(at root: URL, save: Bool = true) throws -> LibraryPaths {
        let paths = LibraryPaths(root: root)
        let directories = [
            paths.root,
            paths.inbox,
            paths.packs,
            paths.collections,
            paths.exports,
            paths.databaseDirectory,
            paths.thumbnails,
            paths.manifests
        ]

        for directory in directories {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        if save {
            saveRoot(root)
        }
        return paths
    }

    private static func missingVolumeName(for root: URL) -> String? {
        let path = root.standardizedFileURL.path
        guard path.hasPrefix("/Volumes/") else { return nil }
        let parts = path.split(separator: "/")
        guard parts.count >= 2 else { return nil }
        let volumeName = String(parts[1])
        let volumeURL = URL(fileURLWithPath: "/Volumes/\(volumeName)", isDirectory: true)
        return directoryExists(volumeURL) ? nil : volumeName
    }
}
