//
//  GenericImportModelsTests.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import XCTest
@testable import Crate

final class GenericImportModelsTests: XCTestCase {
    func testDescriptorInfersPaperTexturePack() {
        let url = URL(fileURLWithPath: "/tmp/Crate Sample Paper Textures", isDirectory: true)
        let descriptor = GenericPackDescriptor(sourceURL: url)

        XCTAssertEqual(descriptor.displayName, "Crate Sample Paper Textures")
        XCTAssertEqual(descriptor.packID, "crate-sample-paper-textures")
        XCTAssertEqual(descriptor.kind, "texture")
        XCTAssertEqual(descriptor.kindPlural, "textures")
        XCTAssertEqual(descriptor.material, "paper")
        XCTAssertEqual(descriptor.subtype, "crate-sample-paper")
    }

    func testDescriptorKeepsExplicitOverrides() {
        let url = URL(fileURLWithPath: "/tmp/Whatever", isDirectory: true)
        let descriptor = GenericPackDescriptor(
            sourceURL: url,
            options: GenericImportOptions(
                displayName: "Fancy Smoke",
                source: "Test Source",
                kind: "overlay",
                material: "atmosphere",
                subtype: "smoke",
                packID: "custom-pack",
                shortCode: "cp"
            )
        )

        XCTAssertEqual(descriptor.displayName, "Fancy Smoke")
        XCTAssertEqual(descriptor.source, "Test Source")
        XCTAssertEqual(descriptor.kind, "overlay")
        XCTAssertEqual(descriptor.kindPlural, "overlays")
        XCTAssertEqual(descriptor.material, "atmosphere")
        XCTAssertEqual(descriptor.subtype, "smoke")
        XCTAssertEqual(descriptor.packID, "custom-pack")
        XCTAssertEqual(descriptor.shortCode, "cp")
    }

    func testVariantRolePairsPNGAndJPG() {
        let descriptor = GenericPackDescriptor(sourceURL: URL(fileURLWithPath: "/tmp/Pack", isDirectory: true))

        XCTAssertEqual(descriptor.variantRole(forExtension: "png", groupedVariantCount: 2), .transparent)
        XCTAssertEqual(descriptor.variantRole(forExtension: "jpg", groupedVariantCount: 2), .flat)
        XCTAssertEqual(descriptor.variantRole(forExtension: "png", groupedVariantCount: 1), .original)
    }
}
