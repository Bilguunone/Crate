//
//  RansomName.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import Foundation

struct RansomName {
    let assetID: String
    let displayName: String
    let fileName: String
    let folderPath: String
    let kind: String
    let tags: [AssetTag]

    static func parse(folder: String, baseName: String) -> RansomName {
        if folder == "_Words" {
            return word(baseName)
        } else if folder == "_Shapes" {
            return shape(baseName)
        } else if folder == "_Special Characters" {
            return symbol(baseName)
        } else if folder.range(of: #"^[A-Z]$"#, options: .regularExpression) != nil {
            return glyph(kind: "letter", group: folder, baseName: baseName, folderPath: "letters/\(folder.lowercased())")
        } else {
            return glyph(kind: "number", group: folder, baseName: baseName, folderPath: "numbers/\(folder)")
        }
    }

    private static func glyph(kind: String, group: String, baseName: String, folderPath: String) -> RansomName {
        let variant = trailingVariant(baseName).variant
        let padded = Slug.paddedNumber(variant)
        let content = group.lowercased()
        let assetID = "rb-ransom-\(kind)-\(content)-\(padded)"
        let fileName = "rb-ransom__\(kind)-\(content)-\(padded).png"
        return RansomName(
            assetID: assetID,
            displayName: "\(kind.capitalized) \(group) \(padded)",
            fileName: fileName,
            folderPath: folderPath,
            kind: kind,
            tags: [
                tag("kind", kind, "path"),
                tag("content", content, "path"),
                tag("use", "title", "pack-rule")
            ]
        )
    }

    private static func word(_ baseName: String) -> RansomName {
        let parsed = trailingVariant(baseName)
        let content = Slug.make(parsed.stem.replacingOccurrences(of: "_", with: " "))
        let padded = Slug.paddedNumber(parsed.variant)
        let assetID = "rb-ransom-word-\(content)-\(padded)"
        let fileName = "rb-ransom__word-\(content)-\(padded).png"
        return RansomName(
            assetID: assetID,
            displayName: "Word \(parsed.stem.replacingOccurrences(of: "_", with: " ")) \(padded)",
            fileName: fileName,
            folderPath: "words",
            kind: "word",
            tags: [
                tag("kind", "word", "path"),
                tag("content", content, "filename"),
                tag("use", "title", "pack-rule"),
                tag("use", "callout", "pack-rule")
            ]
        )
    }

    private static func shape(_ baseName: String) -> RansomName {
        let parsed = trailingVariant(baseName)
        let shape = Slug.make(parsed.stem)
        let padded = Slug.paddedNumber(parsed.variant)
        let assetID = "rb-ransom-shape-\(shape)-\(padded)"
        let fileName = "rb-ransom__shape-\(shape)-\(padded).png"
        return RansomName(
            assetID: assetID,
            displayName: "Shape \(parsed.stem) \(padded)",
            fileName: fileName,
            folderPath: "shapes",
            kind: "shape",
            tags: [
                tag("kind", "shape", "path"),
                tag("shape", shape, "filename"),
                tag("use", "callout", "pack-rule")
            ]
        )
    }

    private static func symbol(_ baseName: String) -> RansomName {
        let parsed = trailingVariant(baseName)
        let symbol = Slug.make(parsed.stem)
        let padded = Slug.paddedNumber(parsed.variant)
        let assetID = "rb-ransom-symbol-\(symbol)-\(padded)"
        let fileName = "rb-ransom__symbol-\(symbol)-\(padded).png"
        return RansomName(
            assetID: assetID,
            displayName: "Symbol \(parsed.stem) \(padded)",
            fileName: fileName,
            folderPath: "symbols",
            kind: "symbol",
            tags: [
                tag("kind", "symbol", "path"),
                tag("content", symbol, "filename"),
                tag("use", "callout", "pack-rule")
            ]
        )
    }

    private static func trailingVariant(_ baseName: String) -> (stem: String, variant: String) {
        let parts = baseName.split(separator: "_").map(String.init)
        guard let last = parts.last, Int(last) != nil, parts.count > 1 else {
            return (baseName, "1")
        }
        return (parts.dropLast().joined(separator: "_"), last)
    }

    private static func tag(_ namespace: String, _ value: String, _ source: String) -> AssetTag {
        AssetTag(namespace: namespace, value: value, source: source, confidence: 1, protected: false)
    }
}
