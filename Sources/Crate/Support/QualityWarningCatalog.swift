//
//  QualityWarningCatalog.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-24.
//

import Foundation

enum QualityWarningCatalog {
    static let orderedValues = [
        "fake-transparency",
        "white-boxed-background",
        "bad-alpha-edges",
        "blurry",
        "low-resolution",
        "giant-file"
    ]

    static func orderedValues(from values: Set<String>) -> [String] {
        orderedValues.filter { values.contains($0) } + values.subtracting(orderedValues).sorted()
    }

    static func title(for value: String) -> String {
        switch value {
        case "fake-transparency": "Fake Transparency"
        case "white-boxed-background": "White Boxed Background"
        case "bad-alpha-edges": "Bad Alpha Edges"
        case "blurry": "Blurry"
        case "low-resolution": "Low Resolution"
        case "giant-file": "Giant File"
        case "suspicious-duplicate": "Suspicious Duplicate"
        default:
            value.replacingOccurrences(of: "-", with: " ").capitalized
        }
    }

    static func detail(for value: String) -> String {
        switch value {
        case "fake-transparency": "PNG says alpha, pixels say nope"
        case "white-boxed-background": "looks cut out, still boxed"
        case "bad-alpha-edges": "possible matte or halo edge"
        case "blurry": "soft beyond useful preview softness"
        case "low-resolution": "small enough to betray you later"
        case "giant-file": "heavy file for the vault"
        case "suspicious-duplicate": "same or almost-same asset"
        default: "needs a quick look"
        }
    }

    static func systemImage(for value: String) -> String {
        switch value {
        case "fake-transparency": "checkerboard.rectangle"
        case "white-boxed-background": "square.dashed.inset.filled"
        case "bad-alpha-edges": "scissors"
        case "blurry": "eye.slash"
        case "low-resolution": "rectangle.compress.vertical"
        case "giant-file": "externaldrive.fill.badge.exclamationmark"
        case "suspicious-duplicate": "square.on.square.intersection.dashed"
        default: "exclamationmark.triangle"
        }
    }
}
