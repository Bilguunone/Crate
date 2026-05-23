//
//  SlugTests.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import XCTest
@testable import Crate

final class SlugTests: XCTestCase {
    func testSlugNormalizesNamesForStableIDs() {
        XCTAssertEqual(Slug.make("Burnt Edge Paper 001.png"), "burnt-edge-paper-001-png")
        XCTAssertEqual(Slug.make("weird @#$ sale!!"), "weird-sale")
        XCTAssertEqual(Slug.make("  Plastic / Wrap  "), "plastic-wrap")
    }

    func testPaddedNumberOnlyPadsNumericValues() {
        XCTAssertEqual(Slug.paddedNumber("7"), "007")
        XCTAssertEqual(Slug.paddedNumber("42", width: 4), "0042")
        XCTAssertEqual(Slug.paddedNumber("paper-7"), "paper-7")
    }
}
