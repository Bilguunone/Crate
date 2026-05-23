//
//  AssetImporter+PresetImports.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import Foundation

extension AssetImporter {
    func importPreset(_ preset: ImportPreset) throws -> (pack: AssetPack, assets: [DesignAsset]) {
        guard fileManager.fileExists(atPath: preset.sourceURL.path) else {
            throw ImportError.missingSource(preset.sourceURL.path)
        }

        try cleanPreviousImport(packID: preset.id)

        let packRoot = paths.packLibraryURL(preset.id)
        let assetsRoot = packRoot.appendingPathComponent("assets", isDirectory: true)
        try fileManager.createDirectory(at: assetsRoot, withIntermediateDirectories: true)

        let assets: [DesignAsset]
        switch preset.packType {
        case .ransomLetters:
            assets = try importRansomLetters(preset, assetsRoot: assetsRoot)
        case .tornPaper:
            assets = try importTornPaper(preset, assetsRoot: assetsRoot)
        case .plasticWrap:
            assets = try importPlasticWrap(preset, assetsRoot: assetsRoot)
        }

        guard !assets.isEmpty else {
            throw ImportError.emptyPack(preset.displayName, preset.sourceURL.path)
        }

        let pack = AssetPack(
            id: preset.id,
            displayName: preset.displayName,
            source: preset.source,
            importedAt: Date(),
            assetCount: assets.count
        )

        try writeManifest(pack: pack, preset: preset, assets: assets, packRoot: packRoot)
        return (pack, assets)
    }

    func importRansomLetters(_ preset: ImportPreset, assetsRoot: URL) throws -> [DesignAsset] {
        var output: [DesignAsset] = []
        for sourceURL in imageFiles(in: preset.sourceURL) where sourceURL.pathExtension.lowercased() == "png" {
            let folder = sourceURL.deletingLastPathComponent().lastPathComponent
            let baseName = sourceURL.deletingPathExtension().lastPathComponent
            let parsed = RansomName.parse(folder: folder, baseName: baseName)

            let destinationDirectory = assetsRoot
                .appendingPathComponent(parsed.folderPath, isDirectory: true)
            try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

            let destinationURL = destinationDirectory.appendingPathComponent(parsed.fileName)
            try copyReplacing(sourceURL, to: destinationURL)

            guard let metadata = ImageMetadataReader.read(destinationURL) else { continue }
            let assetID = parsed.assetID
            let variant = AssetVariant(
                id: "\(assetID)-original",
                assetID: assetID,
                role: .original,
                fileURL: destinationURL,
                originalFileName: sourceURL.lastPathComponent,
                fileExtension: "png",
                width: metadata.width,
                height: metadata.height,
                hasAlpha: metadata.hasAlpha,
                byteCount: metadata.byteCount
            )

            let thumbnailURL = try ThumbnailService.generateThumbnail(
                sourceURL: destinationURL,
                assetID: assetID,
                paths: paths,
                preservesAlpha: variant.hasAlpha
            )
            output.append(
                DesignAsset(
                    id: assetID,
                    packID: preset.id,
                    displayName: parsed.displayName,
                    normalizedName: parsed.fileName,
                    primaryVariantID: variant.id,
                    kind: parsed.kind,
                    createdAt: Date(),
                    variants: [variant],
                    tags: withComputedTags(
                        parsed.tags + baseTags(preset: preset, material: "paper", subtype: "ransom-note"),
                        primary: variant
                    ),
                    thumbnailURL: thumbnailURL
                )
            )
        }
        return output.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    func importTornPaper(_ preset: ImportPreset, assetsRoot: URL) throws -> [DesignAsset] {
        let destinationDirectory = assetsRoot.appendingPathComponent("textures/torn-paper", isDirectory: true)
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        return try imageFiles(in: preset.sourceURL)
            .filter { $0.pathExtension.lowercased() == "png" }
            .compactMap { sourceURL in
                let rawID = sourceURL.deletingPathExtension().lastPathComponent
                let padded = Slug.paddedNumber(rawID)
                let assetID = "rb-torn-paper-\(padded)"
                let fileName = "rb-torn-paper__texture-torn-paper-\(padded).transparent.png"
                let destinationURL = destinationDirectory.appendingPathComponent(fileName)
                try copyReplacing(sourceURL, to: destinationURL)
                guard let metadata = ImageMetadataReader.read(destinationURL) else { return nil }

                let variant = AssetVariant(
                    id: "\(assetID)-transparent",
                    assetID: assetID,
                    role: .transparent,
                    fileURL: destinationURL,
                    originalFileName: sourceURL.lastPathComponent,
                    fileExtension: "png",
                    width: metadata.width,
                    height: metadata.height,
                    hasAlpha: metadata.hasAlpha,
                    byteCount: metadata.byteCount
                )
                let thumbnailURL = try ThumbnailService.generateThumbnail(
                    sourceURL: destinationURL,
                    assetID: assetID,
                    paths: paths,
                    preservesAlpha: variant.hasAlpha
                )
                return DesignAsset(
                    id: assetID,
                    packID: preset.id,
                    displayName: "Torn Paper \(padded)",
                    normalizedName: fileName,
                    primaryVariantID: variant.id,
                    kind: "texture",
                    createdAt: Date(),
                    variants: [variant],
                    tags: withComputedTags(baseTags(preset: preset, material: "paper", subtype: "torn-paper") + [
                        tag("kind", "texture", "pack-rule"),
                        tag("use", "divider", "pack-rule"),
                        tag("use", "collage-edge", "pack-rule"),
                        tag("behavior", "transparent", "metadata", metadata.hasAlpha ? 1 : 0.5),
                        orientationTag(metadata)
                    ], primary: variant),
                    thumbnailURL: thumbnailURL
                )
            }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    func importPlasticWrap(_ preset: ImportPreset, assetsRoot: URL) throws -> [DesignAsset] {
        let destinationDirectory = assetsRoot.appendingPathComponent("overlays/plastic-wrap", isDirectory: true)
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        let groups = Dictionary(grouping: imageFiles(in: preset.sourceURL)) {
            $0.deletingPathExtension().lastPathComponent
        }

        return try groups.keys.sorted(by: numericSort).compactMap { key in
            let padded = Slug.paddedNumber(key)
            let assetID = "rb-plastic-wrap-\(padded)"
            let sourceFiles = (groups[key] ?? []).sorted { $0.pathExtension < $1.pathExtension }
            var variants: [AssetVariant] = []

            for sourceURL in sourceFiles {
                let ext = sourceURL.pathExtension.lowercased()
                let role: AssetVariantRole = ext == "png" ? .transparent : .flat
                let fileName = "rb-plastic-wrap__overlay-plastic-wrap-\(padded).\(role.rawValue).\(ext)"
                let destinationURL = destinationDirectory.appendingPathComponent(fileName)
                try copyReplacing(sourceURL, to: destinationURL)

                guard let metadata = ImageMetadataReader.read(destinationURL) else { continue }
                variants.append(
                    AssetVariant(
                        id: "\(assetID)-\(role.rawValue)",
                        assetID: assetID,
                        role: role,
                        fileURL: destinationURL,
                        originalFileName: sourceURL.lastPathComponent,
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
            return DesignAsset(
                id: assetID,
                packID: preset.id,
                displayName: "Plastic Wrap \(padded)",
                normalizedName: "rb-plastic-wrap__overlay-plastic-wrap-\(padded)",
                primaryVariantID: primary.id,
                kind: "overlay",
                createdAt: Date(),
                variants: variants,
                tags: withComputedTags(baseTags(preset: preset, material: "plastic", subtype: "plastic-wrap") + [
                    tag("kind", "overlay", "pack-rule"),
                    tag("use", "overlay", "pack-rule"),
                    tag("use", "reflection", "pack-rule"),
                    tag("behavior", "transparent", "metadata", variants.contains(where: \.hasAlpha) ? 1 : 0.5),
                    tag("behavior", "full-frame", "pack-rule")
                ], primary: primary),
                thumbnailURL: thumbnailURL
            )
        }
    }
}
