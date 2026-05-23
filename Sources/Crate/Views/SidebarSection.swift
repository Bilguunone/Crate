//
//  SidebarSection.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import Foundation

enum SidebarSection: String, CaseIterable {
    case smartCollections
    case packs
    case kind
    case material
    case use
    case userTags
    case color
    case quality
    case visual
    case collections
    case importing
    case library

    static let defaultExpandedSections = Set(allCases.filter { $0 != .packs })

    var title: String {
        switch self {
        case .smartCollections: "Smart Collections"
        case .packs: "Packs"
        case .kind: "Kind"
        case .material: "Material"
        case .use: "Use"
        case .userTags: "User Tags"
        case .color: "Color"
        case .quality: "Quality"
        case .visual: "Visual"
        case .collections: "Collections"
        case .importing: "Import"
        case .library: "Library"
        }
    }
}
