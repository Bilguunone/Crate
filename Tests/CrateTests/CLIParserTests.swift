//
//  CLIParserTests.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import XCTest
@testable import Crate

final class CLIParserTests: XCTestCase {
    func testSearchOptionsConsumeFlagsAndQuery() {
        var parser = CLIParser(arguments: [
            "--kind", "overlay",
            "--tag", "material:plastic",
            "--tag", "color:white",
            "--alpha",
            "--limit", "7",
            "fold"
        ])

        let options = SearchOptions(parser: &parser)

        XCTAssertEqual(options.kind, "overlay")
        XCTAssertEqual(options.tags, ["material:plastic", "color:white"])
        XCTAssertTrue(options.alphaOnly)
        XCTAssertEqual(options.limit, 7)
        XCTAssertEqual(options.query, "fold")
    }

    func testRemainingNonOptionsLeavesFlagsBehind() {
        var parser = CLIParser(arguments: ["one", "--flag", "two", "--other"])

        XCTAssertEqual(parser.remainingNonOptions(), ["one", "two"])
        XCTAssertTrue(parser.hasFlag("--flag"))
        XCTAssertTrue(parser.hasFlag("--other"))
    }
}
