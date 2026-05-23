//
//  CrateCLI+Output.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import Foundation

extension CrateCLI {
    func printHelp() {
        print("""
        cratectl controls the local Crate library.
        Add --json to status, packs, search, show, similar, cart list, favorite list, tag list, or collection list for structured output.

        Usage:
          cratectl [--library <path>] status
          cratectl [--library <path>] packs
          cratectl analyze-folder <path> [--json] [--kind k] [--material m] [--subtype s]
          cratectl [--library <path>] import-folder <path> [--kind k] [--material m] [--subtype s]
          cratectl [--library <path>] remove-pack <pack-id> --yes
          cratectl [--library <path>] library validate [--json]
          cratectl [--library <path>] library move <destination-folder> --yes [--save] [--json]
          cratectl [--library <path>] duplicates [--near-threshold n]
          cratectl [--library <path>] repair-thumbnails [--json]
          cratectl [--library <path>] analyze-visual-tags [--json]
          cratectl [--library <path>] search <query> [--kind k] [--tag ns:value] [--alpha] [--limit n]
          cratectl [--library <path>] show <asset-id>
          cratectl [--library <path>] similar <asset-id> [--limit n]
          cratectl [--library <path>] cart list
          cratectl [--library <path>] cart add <asset-id> [asset-id...]
          cratectl [--library <path>] cart add-search <query> [--kind k] [--tag ns:value] [--limit n]
          cratectl [--library <path>] cart remove <asset-id> [asset-id...]
          cratectl [--library <path>] cart clear
          cratectl [--library <path>] cart export-folder
          cratectl [--library <path>] cart export-zip
          cratectl [--library <path>] favorite list
          cratectl [--library <path>] favorite add <asset-id> [asset-id...]
          cratectl [--library <path>] favorite remove <asset-id> [asset-id...]
          cratectl [--library <path>] favorite toggle <asset-id> [asset-id...]
          cratectl [--library <path>] tag list <asset-id>
          cratectl [--library <path>] tag add <asset-id> <tag> [tag...]
          cratectl [--library <path>] tag remove <asset-id> <tag> [tag...]
          cratectl [--library <path>] collection list
          cratectl [--library <path>] collection create <name> [--from-cart | --asset id...]
        """)
    }

    func printJSON<T: Encodable>(_ value: T) throws {
        let data = try DateCoding.encoder.encode(value)
        print(String(decoding: data, as: UTF8.self))
    }

    func printDuplicateGroups(_ label: String, _ groups: [DuplicateCluster]) {
        guard !groups.isEmpty else { return }
        print("\(label):")
        for group in groups.prefix(20) {
            let distance = group.distance.map { " distance=\($0)" } ?? ""
            print("  \(group.assetIDs.joined(separator: ", "))\(distance)")
        }
    }

    func printLibraryValidation(_ report: LibraryValidationReport) {
        print("library: \(report.root.path)")
        print("summary: \(report.summary)")
        print("database: \(report.databaseExists ? "ok" : "missing")")
        print("packs: \(report.packCount)")
        print("assets: \(report.assetCount)")
        print("variants: \(report.variantCount)")
        print("missing_directories: \(report.missingDirectories.joined(separator: ", "))")
        print("missing_variant_files: \(report.missingVariantFileCount)")
        print("missing_thumbnails: \(report.missingThumbnailCount)")
        print("missing_manifests: \(report.missingManifestCount)")
    }
}
