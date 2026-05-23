//
//  AppModel+Importing.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import AppKit
import Foundation

extension AppModel {
    func importPresetPacks() async {
        guard let paths, let store else {
            statusMessage = "Choose a library before importing."
            return
        }

        isImporting = true
        defer { isImporting = false }

        let importer = AssetImporter(paths: paths)
        do {
            for preset in ImportPresetCatalog.resourceBoy {
                guard let resolvedPreset = resolvePresetSource(preset) else {
                    statusMessage = "Import canceled for \(preset.displayName)."
                    continue
                }
                statusMessage = "Importing \(resolvedPreset.displayName)..."
                let result = try importer.importPreset(resolvedPreset)
                try store.replacePack(result.pack, assets: result.assets)
                await Task.yield()
            }
            try reload()
            if assets.isEmpty {
                statusMessage = "No assets imported yet. Use Import Folder for any pack, or Import Presets if you still have those exact Resource Boy folders."
            } else {
                let message = "Imported \(packs.count) packs, \(assets.count) assets. Much better than Downloads soup."
                statusMessage = message
                scanDuplicatesAfterImport(importMessage: message)
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func chooseAndImportFolder() {
        guard hasLibrary else {
            statusMessage = "Choose a Crate library first."
            return
        }

        let panel = NSOpenPanel()
        panel.title = "Import Asset Folder"
        panel.message = "Pick a folder that contains PNG/JPG assets. Crate will copy it into the managed library; originals stay untouched."
        panel.prompt = "Import Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads", isDirectory: true)

        guard panel.runModal() == .OK, let url = panel.url else { return }
        prepareImportReview(for: url)
    }

    func prepareImportReview(for url: URL) {
        do {
            let analysis = try ImportFolderAnalyzer.analyze(sourceURL: url)
            importReviewDraft = ImportReviewDraft(sourceURL: url, analysis: analysis)
            statusMessage = "Reviewing \(analysis.displayName)."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func refreshImportReview() {
        guard var draft = importReviewDraft else { return }
        do {
            draft.analysis = try ImportFolderAnalyzer.analyze(sourceURL: draft.sourceURL, options: draft.options)
            importReviewDraft = draft
            statusMessage = "Updated import plan for \(draft.displayName)."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func scheduleImportReviewRefresh() {
        importReviewRefreshTask?.cancel()
        importReviewRefreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            self?.refreshImportReview()
        }
    }

    func cancelImportReview() {
        importReviewRefreshTask?.cancel()
        importReviewDraft = nil
    }

    func confirmImportReview() async {
        guard let draft = importReviewDraft else { return }
        importReviewRefreshTask?.cancel()
        importReviewDraft = nil
        await importFolder(draft.sourceURL, options: draft.options)
    }

    func importFolder(_ url: URL, options: GenericImportOptions = GenericImportOptions()) async {
        guard let paths, let store else {
            statusMessage = "Choose a library before importing."
            return
        }

        isImporting = true
        defer { isImporting = false }

        do {
            statusMessage = "Importing \(url.lastPathComponent)..."
            let importer = AssetImporter(paths: paths)
            let result = try importer.importGenericFolder(url, options: options)
            try store.replacePack(result.pack, assets: result.assets)
            try reload()
            selectedFilter = .pack(result.pack.id)
            refreshFilteredAssets(selectFirst: true)
            let message = "Imported \(result.assets.count) assets from \(result.pack.displayName). Finally, something to look at."
            statusMessage = message
            scanDuplicatesAfterImport(importMessage: message)
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

private extension AppModel {
    func resolvePresetSource(_ preset: ImportPreset) -> ImportPreset? {
        if let savedURL = savedPresetSource(for: preset), isReadableDirectory(savedURL) {
            return preset.withSourceURL(savedURL)
        }

        if isReadableDirectory(preset.sourceURL) {
            return preset
        }

        guard let chosenURL = chooseSourceFolder(for: preset) else {
            return nil
        }

        savePresetSource(chosenURL, for: preset)
        return preset.withSourceURL(chosenURL)
    }

    func chooseSourceFolder(for preset: ImportPreset) -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Locate \(preset.displayName)"
        panel.message = "Crate cannot see the original folder. Pick the folder named “\(preset.displayName)” or wherever you moved that pack."
        panel.prompt = "Use This Pack"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads", isDirectory: true)

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }
        return url
    }

    func isReadableDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    func savedPresetSource(for preset: ImportPreset) -> URL? {
        guard let value = UserDefaults.standard.string(forKey: presetSourceKey(preset.id)), !value.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: value, isDirectory: true)
    }

    func savePresetSource(_ url: URL, for preset: ImportPreset) {
        UserDefaults.standard.set(url.path, forKey: presetSourceKey(preset.id))
    }

    func presetSourceKey(_ presetID: String) -> String {
        "Crate.ImportPresetSource.\(presetID)"
    }
}

private extension ImportPreset {
    func withSourceURL(_ sourceURL: URL) -> ImportPreset {
        ImportPreset(
            id: id,
            displayName: displayName,
            shortCode: shortCode,
            source: source,
            sourceURL: sourceURL,
            packType: packType
        )
    }
}
