//
//  CrateCLIModels.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import Foundation

struct CLIStatus: Codable {
    let library: String
    let packs: Int
    let assets: Int
    let cart: Int
    let collections: Int
}

struct CLILibraryMigrationRecord: Codable {
    let sourceRoot: String
    let destinationRoot: String
    let removedSource: Bool
    let validationReport: LibraryValidationReport

    init(result: LibraryMigrationResult) {
        sourceRoot = result.sourceRoot.path
        destinationRoot = result.destinationRoot.path
        removedSource = result.removedSource
        validationReport = result.validationReport
    }
}

struct CLIThumbnailRepairReport: Codable {
    let scannedAssets: Int
    let updatedAssets: Int
    let regeneratedThumbnails: Int
    let removedStaleThumbnails: Int
    let failedAssetIDs: [String]
}

struct CLIPackRecord: Codable {
    let id: String
    let displayName: String
    let source: String
    let importedAt: Date
    let assetCount: Int

    init(pack: AssetPack) {
        id = pack.id
        displayName = pack.displayName
        source = pack.source
        importedAt = pack.importedAt
        assetCount = pack.assetCount
    }
}

struct CLIAssetRecord: Codable {
    let id: String
    let packID: String
    let displayName: String
    let normalizedName: String
    let kind: String
    let hasAlpha: Bool
    let primaryPath: String?
    let thumbnailPath: String?
    let tags: [String]
    let userTags: [String]
    let isFavorite: Bool

    init(asset: DesignAsset, isFavorite: Bool = false) {
        id = asset.id
        packID = asset.packID
        displayName = asset.displayName
        normalizedName = asset.normalizedName
        kind = asset.kind
        hasAlpha = asset.hasAlpha
        primaryPath = asset.primaryVariant?.fileURL.path
        thumbnailPath = asset.thumbnailURL?.path
        tags = asset.tags.map { "\($0.namespace):\($0.value)" }.sorted()
        userTags = asset.tags
            .filter { $0.source == "user" && $0.protected }
            .map { "\($0.namespace):\($0.value)" }
            .sorted()
        self.isFavorite = isFavorite
    }
}

struct CLIAssetDetail: Codable {
    let asset: CLIAssetRecord
    let variants: [CLIVariantRecord]
    let detailedTags: [CLITagRecord]

    init(asset: DesignAsset, isFavorite: Bool = false) {
        self.asset = CLIAssetRecord(asset: asset, isFavorite: isFavorite)
        variants = asset.variants.map(CLIVariantRecord.init(variant:))
        detailedTags = asset.tags.sorted { lhs, rhs in
            if lhs.namespace == rhs.namespace { return lhs.value < rhs.value }
            return lhs.namespace < rhs.namespace
        }.map(CLITagRecord.init(tag:))
    }
}

struct CLIVariantRecord: Codable {
    let id: String
    let role: String
    let path: String
    let originalFileName: String
    let fileExtension: String
    let width: Int
    let height: Int
    let hasAlpha: Bool
    let byteCount: Int64

    init(variant: AssetVariant) {
        id = variant.id
        role = variant.role.rawValue
        path = variant.fileURL.path
        originalFileName = variant.originalFileName
        fileExtension = variant.fileExtension
        width = variant.width
        height = variant.height
        hasAlpha = variant.hasAlpha
        byteCount = variant.byteCount
    }
}

struct CLITagRecord: Codable {
    let namespace: String
    let value: String
    let source: String
    let confidence: Double
    let protected: Bool

    init(tag: AssetTag) {
        namespace = tag.namespace
        value = tag.value
        source = tag.source
        confidence = tag.confidence
        protected = tag.protected
    }
}

struct CLICartItemRecord: Codable {
    let id: String
    let addedAt: Date
    let exportName: String?
    let note: String?
    let asset: CLIAssetRecord

    init(item: CartItem, asset: DesignAsset) {
        id = item.id
        addedAt = item.addedAt
        exportName = item.exportName
        note = item.note
        self.asset = CLIAssetRecord(asset: asset)
    }
}

struct CLICollectionRecord: Codable {
    let id: String
    let name: String
    let coverAssetID: String?
    let createdAt: Date
    let assetIDs: [String]

    init(collection: AssetCollection) {
        id = collection.id
        name = collection.name
        coverAssetID = collection.coverAssetID
        createdAt = collection.createdAt
        assetIDs = collection.assetIDs
    }
}

extension GenericImportOptions {
    init(parser: inout CLIParser) {
        self.init(
            displayName: parser.option("--display-name"),
            source: parser.option("--source"),
            kind: parser.option("--kind"),
            material: parser.option("--material"),
            subtype: parser.option("--subtype"),
            packID: parser.option("--pack-id"),
            shortCode: parser.option("--short-code")
        )
    }
}

struct CLIContext {
    let paths: LibraryPaths
    let store: AssetStore

    init(libraryRoot: URL) throws {
        paths = try LibraryManager.prepareLibrary(at: libraryRoot, save: false)
        store = try AssetStore(databaseURL: paths.databaseURL)
    }
}

struct SearchOptions {
    var query: String
    var kind: String?
    var tags: [String]
    var alphaOnly: Bool
    var limit: Int

    init(parser: inout CLIParser, defaultLimit: Int = 20) {
        kind = parser.option("--kind")
        tags = parser.values(for: "--tag")
        alphaOnly = parser.hasFlag("--alpha")
        limit = parser.intOption("--limit") ?? defaultLimit
        query = parser.nextNonOption() ?? ""
    }
}

struct CLIParser {
    private var arguments: [String]

    init(arguments: [String]) {
        self.arguments = arguments
    }

    mutating func next() -> String? {
        guard !arguments.isEmpty else { return nil }
        return arguments.removeFirst()
    }

    mutating func nextNonOption() -> String? {
        guard let index = arguments.firstIndex(where: { !$0.hasPrefix("--") }) else { return nil }
        return arguments.remove(at: index)
    }

    mutating func option(_ name: String) -> String? {
        guard let index = arguments.firstIndex(of: name),
              arguments.indices.contains(index + 1)
        else { return nil }
        let value = arguments[index + 1]
        arguments.remove(at: index + 1)
        arguments.remove(at: index)
        return value
    }

    mutating func values(for name: String) -> [String] {
        var output: [String] = []
        while let value = option(name) {
            output.append(value)
        }
        return output
    }

    mutating func intOption(_ name: String) -> Int? {
        option(name).flatMap(Int.init)
    }

    mutating func hasFlag(_ name: String) -> Bool {
        guard let index = arguments.firstIndex(of: name) else { return false }
        arguments.remove(at: index)
        return true
    }

    mutating func remainingNonOptions() -> [String] {
        let values = arguments.filter { !$0.hasPrefix("--") }
        arguments.removeAll { !$0.hasPrefix("--") }
        return values
    }
}

enum CLIError: Error, LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let message): message
        }
    }
}
