//
//  LibraryMaintenanceServiceTests.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import XCTest
@testable import Crate

final class LibraryMaintenanceServiceTests: XCTestCase {
    func testVolumeRootDestinationUsesCurrentLibraryName() {
        let destination = LibraryMaintenanceService.proposedDestinationRoot(
            selectedURL: URL(fileURLWithPath: "/Volumes/Design Drive", isDirectory: true),
            currentRoot: URL(fileURLWithPath: "/tmp/DesignAssets", isDirectory: true)
        )

        XCTAssertEqual(destination.path, "/Volumes/Design Drive/DesignAssets")
    }

    func testFolderDestinationIsUsedDirectly() {
        let destination = LibraryMaintenanceService.proposedDestinationRoot(
            selectedURL: URL(fileURLWithPath: "/Volumes/Design Drive/CrateLibrary", isDirectory: true),
            currentRoot: URL(fileURLWithPath: "/tmp/DesignAssets", isDirectory: true)
        )

        XCTAssertEqual(destination.path, "/Volumes/Design Drive/CrateLibrary")
    }
}
