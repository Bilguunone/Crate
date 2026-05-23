//
//  ImportFolderAnalyzer.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-22.
//

import Foundation

enum ImportFolderAnalyzer {
    static func analyze(sourceURL: URL, options: GenericImportOptions = GenericImportOptions()) throws -> ImportFolderAnalysis {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ImportError.missingSource(sourceURL.path)
        }

        let descriptor = GenericPackDescriptor(sourceURL: sourceURL, options: options)
        let files = allFiles(in: sourceURL)
        let imageFiles = files.filter(\.isSupportedImage)
        let ignoredFiles = files.filter { !$0.isSupportedImage }
        let extensionCounts = Dictionary(grouping: imageFiles, by: { $0.pathExtension.lowercased() })
            .mapValues(\.count)

        let groups = Dictionary(grouping: imageFiles) { groupKey($0, root: sourceURL) }
        let basenameGroups = Dictionary(grouping: imageFiles) { $0.deletingPathExtension().lastPathComponent.lowercased() }
        let riskyBasenames = basenameGroups
            .filter { _, files in Set(files.map { $0.deletingLastPathComponent().relativePath(from: sourceURL) }).count > 1 }
            .keys
            .sorted()

        let topLevelFolders = Dictionary(grouping: imageFiles) { url in
            let relative = url.relativePath(from: sourceURL)
            return relative.split(separator: "/").first.map(String.init) ?? "."
        }
        .mapValues(\.count)

        let samplePlans = groups.keys.sorted(by: localizedSort).prefix(12).map { key in
            ImportSamplePlan(
                groupKey: key,
                assetID: "\(descriptor.shortCode)-\(descriptor.normalizedKey(key))",
                displayName: descriptor.displayName(for: key),
                variantCount: groups[key]?.count ?? 0,
                sourceFiles: (groups[key] ?? []).map { $0.relativePath(from: sourceURL) }.sorted()
            )
        }

        return ImportFolderAnalysis(
            sourcePath: sourceURL.path,
            displayName: descriptor.displayName,
            packID: descriptor.packID,
            shortCode: descriptor.shortCode,
            source: descriptor.source,
            inferredKind: descriptor.kind,
            inferredMaterial: descriptor.material,
            inferredSubtype: descriptor.subtype,
            imageCount: imageFiles.count,
            ignoredFileCount: ignoredFiles.count,
            ignoredFileSamples: Array(ignoredFiles
                .map { $0.relativePath(from: sourceURL) }
                .sorted()
                .prefix(12)),
            extensionCounts: extensionCounts,
            variantGroupCount: groups.count,
            multiVariantGroupCount: groups.values.filter { $0.count > 1 }.count,
            riskyDuplicateBasenames: Array(riskyBasenames.prefix(20)),
            topLevelFolders: topLevelFolders,
            samplePlans: samplePlans,
            suggestedCommand: suggestedCommand(sourceURL: sourceURL, descriptor: descriptor)
        )
    }

    private static func allFiles(in directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return enumerator.compactMap { $0 as? URL }.filter { url in
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
            return values?.isRegularFile == true
        }
    }

    private static func groupKey(_ fileURL: URL, root: URL) -> String {
        let relative = fileURL.deletingPathExtension().relativePath(from: root)
        return relative.isEmpty ? fileURL.deletingPathExtension().lastPathComponent : relative
    }

    private static func localizedSort(_ lhs: String, _ rhs: String) -> Bool {
        lhs.localizedStandardCompare(rhs) == .orderedAscending
    }

    private static func suggestedCommand(sourceURL: URL, descriptor: GenericPackDescriptor) -> String {
        """
        ./script/cratectl.sh import-folder "\(sourceURL.path)" --kind \(descriptor.kind) --material \(descriptor.material) --subtype \(descriptor.subtype) --display-name "\(descriptor.displayName)" --source "\(descriptor.source)"
        """
    }
}

struct ImportFolderAnalysis: Codable {
    let sourcePath: String
    let displayName: String
    let packID: String
    let shortCode: String
    let source: String
    let inferredKind: String
    let inferredMaterial: String
    let inferredSubtype: String
    let imageCount: Int
    let ignoredFileCount: Int
    let ignoredFileSamples: [String]
    let extensionCounts: [String: Int]
    let variantGroupCount: Int
    let multiVariantGroupCount: Int
    let riskyDuplicateBasenames: [String]
    let topLevelFolders: [String: Int]
    let samplePlans: [ImportSamplePlan]
    let suggestedCommand: String
}

struct ImportSamplePlan: Codable {
    let groupKey: String
    let assetID: String
    let displayName: String
    let variantCount: Int
    let sourceFiles: [String]
}
