//
//  AppModel+Library.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import AppKit
import Foundation

extension AppModel {
    func bootstrap() async {
        guard let savedRoot = LibraryManager.savedRoot() else { return }
        guard LibraryManager.directoryExists(savedRoot) else {
            isLibraryOpen = false
            missingLibraryRoot = savedRoot
            statusMessage = LibraryManager.missingLibraryMessage(for: savedRoot)
            return
        }
        do {
            try openLibrary(at: savedRoot)
            statusMessage = "Library loaded: \(savedRoot.path)"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func useSuggestedLibrary() {
        do {
            try openLibrary(at: LibraryManager.suggestedRoot)
            statusMessage = "Library ready: \(LibraryManager.suggestedRoot.path)"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func chooseLibraryFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Crate Library"
        panel.prompt = "Use Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = preferredLibraryPickerURL()

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try openLibrary(at: url)
            statusMessage = "Library ready: \(url.path)"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func forgetMissingLibrary() {
        LibraryManager.clearSavedRoot()
        stopLibraryChangePolling()
        isLibraryOpen = false
        missingLibraryRoot = nil
        statusMessage = "Forgot missing library. Choose or create a new one."
    }

    func reloadLibrary() {
        do {
            try reload()
            statusMessage = "Reloaded library."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func chooseLibraryMigrationDestination() {
        guard let sourceRoot = libraryRoot else {
            statusMessage = "Choose a library before moving it."
            return
        }

        let panel = NSOpenPanel()
        panel.title = "Move Crate Library"
        panel.message = "Pick the new library folder on your external drive. If you pick the drive itself, Crate will create \(sourceRoot.lastPathComponent)."
        panel.prompt = "Move Here"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Volumes", isDirectory: true)

        guard panel.runModal() == .OK, let selectedURL = panel.url else { return }
        pendingLibraryMigration = LibraryMigrationPlan(
            sourceRoot: sourceRoot,
            destinationRoot: LibraryMaintenanceService.proposedDestinationRoot(
                selectedURL: selectedURL,
                currentRoot: sourceRoot
            )
        )
    }

    func cancelLibraryMigration() {
        pendingLibraryMigration = nil
    }

    func confirmLibraryMigration() async {
        guard let plan = pendingLibraryMigration else { return }
        pendingLibraryMigration = nil
        isMigratingLibrary = true
        statusMessage = "Moving library to \(plan.destinationRoot.path)..."

        isLibraryOpen = false
        stopLibraryChangePolling()
        store = nil
        paths = nil

        do {
            let result = try await Task.detached(priority: .utility) {
                try LibraryMaintenanceService.moveLibrary(from: plan.sourceRoot, to: plan.destinationRoot)
            }.value
            try openLibrary(at: result.destinationRoot)
            libraryValidationReport = result.validationReport
            statusMessage = result.removedSource
                ? "Moved library to \(result.destinationRoot.path). \(result.validationReport.summary)"
                : "Moved library to \(result.destinationRoot.path), but the old copy could not be removed. \(result.validationReport.summary)"
        } catch {
            if LibraryManager.directoryExists(plan.sourceRoot) {
                try? openLibrary(at: plan.sourceRoot)
            }
            statusMessage = error.localizedDescription
        }

        isMigratingLibrary = false
    }

    func validateLibrary() {
        guard let libraryRoot else {
            statusMessage = "Choose a library before validating."
            return
        }

        isValidatingLibrary = true
        statusMessage = "Validating library..."

        Task { [weak self] in
            do {
                let report = try await Task.detached(priority: .utility) {
                    try LibraryMaintenanceService.validateLibrary(at: libraryRoot)
                }.value
                self?.libraryValidationReport = report
                self?.statusMessage = report.summary
            } catch {
                self?.statusMessage = error.localizedDescription
            }
            self?.isValidatingLibrary = false
        }
    }

    func reload() throws {
        guard let store else { return }
        try CrateTelemetry.measure("library.reload") {
            packs = try store.fetchPacks()
            assets = try store.fetchAssets()
            cartItems = try store.fetchCart()
            collections = try store.fetchCollections()
            usedAssetIDs = try store.fetchUsageAssetIDs()
            favoriteAssetIDs = try store.fetchFavoriteAssetIDs()
            rebuildLibraryCaches()
            refreshFilteredAssets()
            refreshSelectedAssetDerivedData()
            updateLibraryDatabaseSignature()
        }
    }
}

private extension AppModel {
    func openLibrary(at root: URL) throws {
        isLibraryOpen = false
        stopLibraryChangePolling()
        let preparedPaths = try LibraryManager.prepareLibrary(at: root)
        paths = preparedPaths
        store = try AssetStore(databaseURL: preparedPaths.databaseURL)
        libraryRoot = root
        missingLibraryRoot = nil
        libraryValidationReport = nil
        try reload()
        isLibraryOpen = true
        startLibraryChangePolling()
    }

    func preferredLibraryPickerURL() -> URL {
        if let missingLibraryRoot {
            let parent = missingLibraryRoot.deletingLastPathComponent()
            if LibraryManager.directoryExists(parent) {
                return parent
            }
            return URL(fileURLWithPath: "/Volumes", isDirectory: true)
        }
        return LibraryManager.suggestedRoot.deletingLastPathComponent()
    }

    func startLibraryChangePolling() {
        stopLibraryChangePolling()
        updateLibraryDatabaseSignature()

        libraryChangePollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }
                self?.reloadIfLibraryDatabaseChanged()
            }
        }
    }

    func stopLibraryChangePolling() {
        libraryChangePollingTask?.cancel()
        libraryChangePollingTask = nil
        libraryDatabaseSignature = nil
    }

    func reloadIfLibraryDatabaseChanged() {
        guard let paths, isLibraryOpen, !isImporting, !isMigratingLibrary else { return }

        let currentSignature = LibraryDatabaseSignature(paths: paths)
        guard let previousSignature = libraryDatabaseSignature else {
            libraryDatabaseSignature = currentSignature
            return
        }
        guard currentSignature != previousSignature else { return }

        do {
            let selectedID = selectedAssetID
            let previousAssetCount = assets.count
            try reload()
            if let selectedID, assetsByID[selectedID] != nil {
                selectedAssetID = selectedID
            }
            let delta = assets.count - previousAssetCount
            statusMessage = delta == 0
                ? "Library updated outside Crate."
                : "Library updated outside Crate. \(abs(delta)) asset\(abs(delta) == 1 ? "" : "s") \(delta > 0 ? "added" : "removed")."
        } catch {
            statusMessage = error.localizedDescription
            libraryDatabaseSignature = currentSignature
        }
    }

    func updateLibraryDatabaseSignature() {
        guard let paths else {
            libraryDatabaseSignature = nil
            return
        }
        libraryDatabaseSignature = LibraryDatabaseSignature(paths: paths)
    }
}
