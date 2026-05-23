//
//  AssetImporter+GenericImport.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import Foundation

extension AssetImporter {
    func importGenericFolder(_ sourceURL: URL, options: GenericImportOptions = GenericImportOptions()) throws -> (pack: AssetPack, assets: [DesignAsset]) {
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw ImportError.missingSource(sourceURL.path)
        }

        let descriptor = GenericPackDescriptor(sourceURL: sourceURL, options: options)
        try cleanPreviousImport(packID: descriptor.packID)

        let packRoot = paths.packLibraryURL(descriptor.packID)
        let assetsRoot = packRoot.appendingPathComponent("assets", isDirectory: true)
        let destinationDirectory = assetsRoot
            .appendingPathComponent(descriptor.kindPlural, isDirectory: true)
            .appendingPathComponent(descriptor.subtype, isDirectory: true)
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        let groups = Dictionary(grouping: imageFiles(in: sourceURL)) {
            genericGroupKey($0, root: sourceURL)
        }

        let assets = try groups.keys.sorted(by: numericSort).compactMap { key -> DesignAsset? in
            let sourceFiles = (groups[key] ?? []).sorted { lhs, rhs in
                lhs.pathExtension.localizedStandardCompare(rhs.pathExtension) == .orderedAscending
            }
            guard !sourceFiles.isEmpty else { return nil }

            let normalizedKey = descriptor.normalizedKey(key)
            let assetID = "\(descriptor.shortCode)-\(normalizedKey)"
            var variants: [AssetVariant] = []

            for sourceFile in sourceFiles {
                let ext = sourceFile.pathExtension.lowercased()
                let metadataSourceRole = descriptor.variantRole(forExtension: ext, groupedVariantCount: sourceFiles.count)
                let fileName = "\(descriptor.shortCode)__\(descriptor.kind)-\(descriptor.subtype)-\(normalizedKey).\(metadataSourceRole.rawValue).\(ext)"
                let destinationURL = destinationDirectory.appendingPathComponent(fileName)
                try copyReplacing(sourceFile, to: destinationURL)

                guard let metadata = ImageMetadataReader.read(destinationURL) else { continue }
                variants.append(
                    AssetVariant(
                        id: "\(assetID)-\(metadataSourceRole.rawValue)",
                        assetID: assetID,
                        role: metadataSourceRole,
                        fileURL: destinationURL,
                        originalFileName: sourceFile.lastPathComponent,
                        fileExtension: ext,
                        width: metadata.width,
                        height: metadata.height,
                        hasAlpha: metadata.hasAlpha,
                        byteCount: metadata.byteCount
                    )
                )
            }

            guard let primary = variants.first(where: { $0.role == .transparent }) ?? variants.first else { return nil }
            let thumbnailURL = try ThumbnailService.generateThumbnail(
                sourceURL: primary.fileURL,
                assetID: assetID,
                paths: paths,
                preservesAlpha: primary.hasAlpha
            )
            let tags = withComputedTags(
                descriptor.tags(hasAlpha: variants.contains(where: \.hasAlpha), primary: primary),
                primary: primary
            )
            return DesignAsset(
                id: assetID,
                packID: descriptor.packID,
                displayName: descriptor.displayName(for: key),
                normalizedName: "\(descriptor.shortCode)__\(descriptor.kind)-\(descriptor.subtype)-\(normalizedKey)",
                primaryVariantID: primary.id,
                kind: descriptor.kind,
                createdAt: Date(),
                variants: variants,
                tags: tags,
                thumbnailURL: thumbnailURL
            )
        }

        guard !assets.isEmpty else {
            throw ImportError.emptyPack(descriptor.displayName, sourceURL.path)
        }

        let pack = AssetPack(
            id: descriptor.packID,
            displayName: descriptor.displayName,
            source: descriptor.source,
            importedAt: Date(),
            assetCount: assets.count
        )

        try writeGenericManifest(pack: pack, descriptor: descriptor, assets: assets, packRoot: packRoot)
        return (pack, assets)
    }
}
