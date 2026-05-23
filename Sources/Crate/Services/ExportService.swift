//
//  ExportService.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-22.
//

import Foundation

enum ExportService {
    static func exportAssetsFolder(assets: [DesignAsset], paths: LibraryPaths) throws -> URL {
        let folder = paths.exports.appendingPathComponent("Selection-\(timestamp())", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try copyAssets(assets, to: folder)
        return folder
    }

    static func exportCartFolder(items: [CartItem], assetsByID: [String: DesignAsset], paths: LibraryPaths) throws -> URL {
        let folder = paths.exports.appendingPathComponent("Cart-\(timestamp())", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try copyCartItems(items: items, assetsByID: assetsByID, to: folder)
        return folder
    }

    static func exportCartZip(items: [CartItem], assetsByID: [String: DesignAsset], paths: LibraryPaths) throws -> URL {
        let folder = try exportCartFolder(items: items, assetsByID: assetsByID, paths: paths)
        let zipURL = folder.deletingPathExtension().appendingPathExtension("zip")
        if FileManager.default.fileExists(atPath: zipURL.path) {
            try FileManager.default.removeItem(at: zipURL)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--keepParent", folder.lastPathComponent, zipURL.path]
        process.currentDirectoryURL = folder.deletingLastPathComponent()
        try process.run()
        process.waitUntilExit()
        return zipURL
    }

    private static func copyCartItems(items: [CartItem], assetsByID: [String: DesignAsset], to folder: URL) throws {
        for item in items {
            guard let asset = assetsByID[item.assetID], let variant = asset.primaryVariant else { continue }
            let exportName = item.exportName ?? variant.fileURL.lastPathComponent
            let destination = folder.appendingPathComponent(exportName)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: variant.fileURL, to: destination)
        }
    }

    private static func copyAssets(_ assets: [DesignAsset], to folder: URL) throws {
        var usedNames: Set<String> = []
        for asset in assets {
            guard let variant = asset.primaryVariant else { continue }
            let exportName = uniqueFileName(for: variant.fileURL.lastPathComponent, usedNames: &usedNames)
            let destination = folder.appendingPathComponent(exportName)
            try FileManager.default.copyItem(at: variant.fileURL, to: destination)
        }
    }

    private static func uniqueFileName(for fileName: String, usedNames: inout Set<String>) -> String {
        guard usedNames.contains(fileName) else {
            usedNames.insert(fileName)
            return fileName
        }

        let url = URL(fileURLWithPath: fileName)
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var index = 2
        while true {
            let candidate = ext.isEmpty ? "\(base)-\(index)" : "\(base)-\(index).\(ext)"
            if !usedNames.contains(candidate) {
                usedNames.insert(candidate)
                return candidate
            }
            index += 1
        }
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}
