//
//  AssetImporter+Manifest.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import Foundation

extension AssetImporter {
    func writeManifest(pack: AssetPack, preset: ImportPreset, assets: [DesignAsset], packRoot: URL) throws {
        try writeManifest(
            pack: pack,
            source: preset.source,
            rules: rules(for: preset.packType),
            assets: assets,
            packRoot: packRoot
        )
    }

    func writeGenericManifest(pack: AssetPack, descriptor: GenericPackDescriptor, assets: [DesignAsset], packRoot: URL) throws {
        try writeManifest(
            pack: pack,
            source: descriptor.source,
            rules: [
                "category_source": "generic_folder_import",
                "group_variants_by_basename": "true",
                "kind": descriptor.kind,
                "subtype": descriptor.subtype
            ],
            assets: assets,
            packRoot: packRoot
        )
    }

    func writeManifest(pack: AssetPack, source: String, rules: [String: String], assets: [DesignAsset], packRoot: URL) throws {
        let manifestAssets = assets.map { asset in
            ManifestAsset(
                id: asset.id,
                displayName: asset.displayName,
                originalFiles: asset.variants.map(\.originalFileName),
                variants: Dictionary(uniqueKeysWithValues: asset.variants.map {
                    ($0.role.rawValue, $0.fileURL.relativePath(from: packRoot))
                }),
                tags: Dictionary(grouping: asset.tags, by: \.namespace)
                    .mapValues { Array(Set($0.map(\.value))).sorted() }
            )
        }

        let manifest = PackManifest(
            schemaVersion: 1,
            packID: pack.id,
            displayName: pack.displayName,
            source: source,
            importedAt: pack.importedAt,
            importerVersion: "1.0",
            assetCount: assets.count,
            rules: rules,
            assets: manifestAssets
        )

        let data = try DateCoding.encoder.encode(manifest)
        try data.write(to: paths.packManifestURL(pack.id), options: [.atomic])
    }

    func rules(for type: PackType) -> [String: String] {
        switch type {
        case .ransomLetters:
            [
                "category_source": "folder_and_filename",
                "letters": "A-Z folders",
                "words": "_Words filename phrases",
                "symbols": "_Special Characters filename symbols"
            ]
        case .tornPaper:
            [
                "category_source": "pack_rule",
                "png_variant": "transparent"
            ]
        case .plasticWrap:
            [
                "group_variants_by_basename": "true",
                "png_variant": "transparent",
                "jpg_variant": "flat"
            ]
        }
    }
}
