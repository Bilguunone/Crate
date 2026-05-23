//
//  GenericImportModels.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import Foundation

struct GenericImportOptions {
    var displayName: String? = nil
    var source: String? = nil
    var kind: String? = nil
    var material: String? = nil
    var subtype: String? = nil
    var packID: String? = nil
    var shortCode: String? = nil
}

struct GenericPackDescriptor {
    let sourceURL: URL
    let displayName: String
    let packID: String
    let shortCode: String
    let source: String
    let kind: String
    let subtype: String
    let material: String

    init(sourceURL: URL, options: GenericImportOptions = GenericImportOptions()) {
        self.sourceURL = sourceURL
        displayName = options.displayName ?? sourceURL.lastPathComponent
        let slug = Slug.make(displayName)
        packID = options.packID ?? slug

        if slug.hasPrefix("resource-boy-") {
            source = options.source ?? "Resource Boy"
            shortCode = options.shortCode ?? "rb-" + String(slug.dropFirst("resource-boy-".count))
        } else {
            source = options.source ?? "User Import"
            shortCode = options.shortCode ?? slug
        }

        let lower = displayName.lowercased()
        if let kind = options.kind {
            self.kind = kind
        } else if lower.contains("overlay") || lower.contains("flare") || lower.contains("wrap") || lower.contains("fog") || lower.contains("snow") {
            self.kind = "overlay"
        } else if lower.contains("sticker") || lower.contains("element") || lower.contains("marker") || lower.contains("shape") {
            self.kind = "sticker"
        } else {
            self.kind = "texture"
        }

        subtype = options.subtype ?? Self.subtype(from: slug)
        material = options.material ?? Self.material(from: displayName, kind: self.kind)
    }

    var kindPlural: String {
        switch kind {
        case "overlay": "overlays"
        case "sticker": "stickers"
        default: "textures"
        }
    }

    func normalizedKey(_ original: String) -> String {
        let slug = Slug.make(original)
        if Int(original) != nil {
            return Slug.paddedNumber(original)
        }
        return slug.isEmpty ? UUID().uuidString.lowercased() : slug
    }

    func displayName(for original: String) -> String {
        let readable = original
            .replacingOccurrences(of: "/", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        if Int(original) != nil {
            return "\(subtype.replacingOccurrences(of: "-", with: " ").capitalized) \(Slug.paddedNumber(original))"
        }
        return readable.capitalized
    }

    func variantRole(forExtension ext: String, groupedVariantCount: Int) -> AssetVariantRole {
        if ext == "png" {
            return groupedVariantCount > 1 ? .transparent : .original
        }
        if ext == "jpg" || ext == "jpeg" {
            return groupedVariantCount > 1 ? .flat : .original
        }
        return .original
    }

    func tags(hasAlpha: Bool, primary: AssetVariant) -> [AssetTag] {
        [
            tag("source_pack", packID, "path"),
            tag("kind", kind, "filename"),
            tag("subtype", subtype, "filename"),
            tag("material", material, "filename"),
            tag("use", useTag, "filename"),
            tag("behavior", hasAlpha ? "transparent" : "flat", "metadata"),
            orientationTag(primary)
        ]
    }

    private static func material(from displayName: String, kind: String) -> String {
        let lower = displayName.lowercased()
        if lower.contains("paper") { return "paper" }
        if lower.contains("plastic") || lower.contains("wrap") { return "plastic" }
        if lower.contains("chalk") { return "chalk" }
        if lower.contains("duct") || lower.contains("tape") { return "tape" }
        if lower.contains("cloud") || lower.contains("fog") || lower.contains("snow") { return "atmosphere" }
        if lower.contains("fire") || lower.contains("flame") { return "fire" }
        if lower.contains("scribble") || lower.contains("marker") { return "ink" }
        return kind
    }

    private var useTag: String {
        switch kind {
        case "overlay": "overlay"
        case "sticker": "sticker"
        default: "background"
        }
    }

    private static func subtype(from slug: String) -> String {
        var words = slug
            .replacingOccurrences(of: "resource-boy-", with: "")
            .replacingOccurrences(of: "-textures", with: "")
            .replacingOccurrences(of: "-overlays", with: "")
            .replacingOccurrences(of: "-elements", with: "")
            .replacingOccurrences(of: "-png", with: "")

        if words.isEmpty {
            words = "asset"
        }
        return words
    }

    private func tag(_ namespace: String, _ value: String, _ source: String) -> AssetTag {
        AssetTag(namespace: namespace, value: value, source: source, confidence: 0.82, protected: false)
    }

    private func orientationTag(_ variant: AssetVariant) -> AssetTag {
        let value: String
        if variant.width > variant.height * 2 {
            value = "long-strip"
        } else if variant.width > variant.height {
            value = "horizontal"
        } else if variant.height > variant.width {
            value = "vertical"
        } else {
            value = "square"
        }
        return tag("shape", value, "metadata")
    }
}

enum ImportError: Error, LocalizedError {
    case missingSource(String)
    case emptyPack(String, String)

    var errorDescription: String? {
        switch self {
        case .missingSource(let path): "Import source does not exist: \(path)"
        case .emptyPack(let name, let path): "No supported assets found for \(name) at \(path). Pick the actual pack folder, not its parent folder."
        }
    }
}
