//
//  AssetImporter+Utilities.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import Foundation

extension AssetImporter {
    func cleanPreviousImport(packID: String) throws {
        let pathsToRemove = [
            paths.packLibraryURL(packID),
            paths.packManifestURL(packID)
        ]

        for url in pathsToRemove where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    func imageFiles(in directory: URL) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return enumerator
            .compactMap { $0 as? URL }
            .filter(\.isSupportedImage)
            .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    func copyReplacing(_ source: URL, to destination: URL) throws {
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: source, to: destination)
    }

    func genericGroupKey(_ fileURL: URL, root: URL) -> String {
        let relative = fileURL.deletingPathExtension().relativePath(from: root)
        return relative.isEmpty ? fileURL.deletingPathExtension().lastPathComponent : relative
    }

    func baseTags(preset: ImportPreset, material: String, subtype: String) -> [AssetTag] {
        [
            tag("source_pack", preset.id, "path"),
            tag("material", material, "pack-rule"),
            tag("subtype", subtype, "pack-rule")
        ]
    }

    func tag(_ namespace: String, _ value: String, _ source: String, _ confidence: Double = 1, protected: Bool = false) -> AssetTag {
        AssetTag(namespace: namespace, value: value, source: source, confidence: confidence, protected: protected)
    }

    func withComputedTags(_ tags: [AssetTag], primary: AssetVariant) -> [AssetTag] {
        tags + VisualAnalysisService.computedTags(for: primary)
    }

    func orientationTag(_ metadata: ImageMetadata) -> AssetTag {
        let value: String
        if metadata.width > metadata.height * 2 {
            value = "long-strip"
        } else if metadata.width > metadata.height {
            value = "horizontal"
        } else if metadata.height > metadata.width {
            value = "vertical"
        } else {
            value = "square"
        }
        return tag("shape", value, "metadata")
    }

    func numericSort(_ lhs: String, _ rhs: String) -> Bool {
        if let left = Int(lhs), let right = Int(rhs) {
            return left < right
        }
        return lhs.localizedStandardCompare(rhs) == .orderedAscending
    }
}
