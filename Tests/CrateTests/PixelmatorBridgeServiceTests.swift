//
//  PixelmatorBridgeServiceTests.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-24.
//

import XCTest
@testable import Crate

final class PixelmatorBridgeServiceTests: XCTestCase {
    func testApplySpecAddsImageLayersWithCrateMetadata() {
        let documentURL = URL(fileURLWithPath: "/tmp/poster.pxd")
        let assets = [
            PixelmatorAssetPayload(
                id: "paper-001",
                displayName: "Burnt Paper 001",
                kind: "texture",
                fileURL: URL(fileURLWithPath: "/tmp/burnt-paper.png"),
                tags: ["kind:texture", "material:paper"]
            ),
            PixelmatorAssetPayload(
                id: "arrow-001",
                displayName: "Arrow 001",
                kind: "sticker",
                fileURL: URL(fileURLWithPath: "/tmp/arrow.png"),
                tags: ["kind:sticker", "shape:arrow"]
            )
        ]

        let spec = PixelmatorBridgeService.applySpec(documentURL: documentURL, assets: assets)

        XCTAssertEqual(spec.document, "/tmp/poster.pxd")
        XCTAssertFalse(spec.save)
        XCTAssertEqual(spec.edits.count, 2)
        XCTAssertEqual(spec.edits[0].op, "add-image")
        XCTAssertEqual(spec.edits[0].name, "Crate: Burnt Paper 001")
        XCTAssertEqual(spec.edits[0].path, "/tmp/burnt-paper.png")
        XCTAssertEqual(spec.edits[0].blendMode, "normal")
        XCTAssertEqual(spec.edits[0].at, "beginning")
        XCTAssertTrue(spec.edits[0].preserveTransparency)
        XCTAssertEqual(spec.edits[0].crateAsset.id, "paper-001")
        XCTAssertEqual(spec.edits[1].crateAsset.tags, ["kind:sticker", "shape:arrow"])
    }
}
