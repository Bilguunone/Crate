//
//  ImportPresetCatalog.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import Foundation

enum ImportPresetCatalog {
    static var resourceBoy: [ImportPreset] {
        [
            resourceBoyPreset(
                id: "resource-boy-ransom-note-letters",
                displayName: "Resource Boy - Ransom Note Letters",
                shortCode: "rb-ransom",
                folderName: "Resource Boy - Ransom Note Letters",
                packType: .ransomLetters
            ),
            resourceBoyPreset(
                id: "resource-boy-torn-paper-textures",
                displayName: "Resource Boy - Torn Paper Textures",
                shortCode: "rb-torn-paper",
                folderName: "Resource Boy - Torn Paper Textures",
                packType: .tornPaper
            ),
            resourceBoyPreset(
                id: "resource-boy-plastic-wrap-textures",
                displayName: "Resource Boy - Plastic Wrap Textures",
                shortCode: "rb-plastic-wrap",
                folderName: "Resource Boy - Plastic Wrap Textures",
                packType: .plasticWrap
            )
        ]
    }

    private static func resourceBoyPreset(
        id: String,
        displayName: String,
        shortCode: String,
        folderName: String,
        packType: PackType
    ) -> ImportPreset {
        ImportPreset(
            id: id,
            displayName: displayName,
            shortCode: shortCode,
            source: "Resource Boy",
            sourceURL: resourceBoyRoot.appendingPathComponent(folderName, isDirectory: true),
            packType: packType
        )
    }

    private static var resourceBoyRoot: URL {
        if let override = ProcessInfo.processInfo.environment["CRATE_RESOURCE_BOY_ROOT"],
           !override.isEmpty {
            return URL(fileURLWithPath: NSString(string: override).expandingTildeInPath, isDirectory: true)
        }

        return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads", isDirectory: true)
    }
}
