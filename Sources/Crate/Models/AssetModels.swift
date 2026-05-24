//
//  AssetModels.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-22.
//

import Foundation

enum AssetVariantRole: String, Codable, CaseIterable, Hashable, Sendable {
    case original
    case transparent
    case flat
    case preview
}

struct AssetPack: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var displayName: String
    var source: String
    var importedAt: Date
    var assetCount: Int
}

struct AssetVariant: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let assetID: String
    var role: AssetVariantRole
    var fileURL: URL
    var originalFileName: String
    var fileExtension: String
    var width: Int
    var height: Int
    var hasAlpha: Bool
    var byteCount: Int64
}

struct AssetTag: Identifiable, Codable, Hashable, Sendable {
    var id: String { "\(namespace):\(value):\(source)" }
    var namespace: String
    var value: String
    var source: String
    var confidence: Double
    var protected: Bool
}

struct DesignAsset: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let packID: String
    var displayName: String
    var normalizedName: String
    var primaryVariantID: String
    var kind: String
    var createdAt: Date
    var variants: [AssetVariant]
    var tags: [AssetTag]
    var thumbnailURL: URL?

    var primaryVariant: AssetVariant? {
        variants.first(where: { $0.id == primaryVariantID }) ?? variants.first
    }

    var hasAlpha: Bool {
        variants.contains(where: \.hasAlpha)
    }

    var tagValues: Set<String> {
        Set(tags.map { "\($0.namespace):\($0.value)" })
    }
}

struct CartItem: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let assetID: String
    let addedAt: Date
    var exportName: String?
    var note: String?
}

enum SidebarFilter: Hashable, Identifiable, Sendable {
    case all
    case pack(String)
    case kind(String)
    case material(String)
    case use(String)
    case alpha
    case tag(String, String)
    case userTag(String, String)
    case smart(SmartCollectionKind)
    case collection(String)
    case shuffle

    var id: String {
        switch self {
        case .all: "all"
        case .pack(let value): "pack:\(value)"
        case .kind(let value): "kind:\(value)"
        case .material(let value): "material:\(value)"
        case .use(let value): "use:\(value)"
        case .alpha: "alpha"
        case .tag(let namespace, let value): "tag:\(namespace):\(value)"
        case .userTag(let namespace, let value): "user-tag:\(namespace):\(value)"
        case .smart(let value): "smart:\(value.rawValue)"
        case .collection(let value): "collection:\(value)"
        case .shuffle: "shuffle"
        }
    }
}

enum AssetAlphaFilter: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case any
    case hasAlpha
    case flat

    var id: String { rawValue }

    var title: String {
        switch self {
        case .any: "Any Alpha"
        case .hasAlpha: "Has Alpha"
        case .flat: "Flat"
        }
    }
}

enum AssetSortMode: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case name
    case newest
    case pack
    case kind
    case largest
    case smallest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name: "Name"
        case .newest: "Newest"
        case .pack: "Pack"
        case .kind: "Kind"
        case .largest: "Largest"
        case .smallest: "Smallest"
        }
    }
}

enum AssetBrowserViewMode: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case grid
    case filmstrip
    case list
    case compare

    var id: String { rawValue }

    var title: String {
        switch self {
        case .grid: "Grid"
        case .filmstrip: "Filmstrip"
        case .list: "List"
        case .compare: "Compare"
        }
    }

    var systemImage: String {
        switch self {
        case .grid: "square.grid.3x3"
        case .filmstrip: "film.stack"
        case .list: "list.bullet.rectangle"
        case .compare: "rectangle.split.3x1"
        }
    }
}

enum SmartCollectionKind: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case recentlyImported
    case favorites
    case hasAlpha
    case unusedGems
    case plasticOverlays
    case paperTextures
    case cart
    case similarToSelected
    case duplicateWatch

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recentlyImported: "Recently Imported"
        case .favorites: "Favorites"
        case .hasAlpha: "Has Alpha"
        case .unusedGems: "Unused Gems"
        case .plasticOverlays: "Plastic Overlays"
        case .paperTextures: "Paper Textures"
        case .cart: "Cart"
        case .similarToSelected: "Similar to Selected"
        case .duplicateWatch: "Duplicate Watch"
        }
    }

    var systemImage: String {
        switch self {
        case .recentlyImported: "clock.arrow.circlepath"
        case .favorites: "heart.fill"
        case .hasAlpha: "checkerboard.rectangle"
        case .unusedGems: "sparkle.magnifyingglass"
        case .plasticOverlays: "film.stack"
        case .paperTextures: "doc.richtext"
        case .cart: "cart"
        case .similarToSelected: "square.stack.3d.up"
        case .duplicateWatch: "square.on.square.intersection.dashed"
        }
    }
}

struct SmartCollectionDefinition: Identifiable, Hashable, Sendable {
    let kind: SmartCollectionKind
    let count: Int
    let detail: String?

    var id: SmartCollectionKind { kind }
    var title: String { kind.title }
    var systemImage: String { kind.systemImage }
}

struct UserTagFacet: Identifiable, Hashable, Sendable {
    let namespace: String
    let value: String
    let count: Int

    var id: String { "\(namespace):\(value)" }
    var title: String { namespace == "user" ? value.capitalized : "\(namespace):\(value)" }
}

struct AssetCollection: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var name: String
    var coverAssetID: String?
    var createdAt: Date
    var assetIDs: [String]
}

struct ImportPreset: Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
    let shortCode: String
    let source: String
    let sourceURL: URL
    let packType: PackType
}

enum PackType: String, Codable, Hashable, Sendable {
    case ransomLetters
    case tornPaper
    case plasticWrap
}
