//
//  AppModel+Pixelmator.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-24.
//

import AppKit
import Foundation
import UniformTypeIdentifiers

extension AppModel {
    func choosePixelmatorBridgeTool() {
        guard let url = choosePXDCTLURL() else { return }
        PixelmatorBridgeService.savePXDCTLURL(url)
        statusMessage = "Pixelmator bridge ready: \(url.path)"
    }

    func sendAssetToOpenPixelmatorProject(_ asset: DesignAsset) {
        sendAssetsToPixelmator(
            [asset],
            preferSelectedVariant: true,
            documentSource: .openProject
        )
    }

    func sendAssetToChosenPixelmatorDocument(_ asset: DesignAsset) {
        sendAssetsToPixelmator(
            [asset],
            preferSelectedVariant: true,
            documentSource: .chooseDocument
        )
    }

    func sendSelectedToOpenPixelmatorProject() {
        sendAssetsToPixelmator(
            selectedAssets,
            preferSelectedVariant: false,
            documentSource: .openProject
        )
    }

    func sendSelectedToChosenPixelmatorDocument() {
        sendAssetsToPixelmator(
            selectedAssets,
            preferSelectedVariant: false,
            documentSource: .chooseDocument
        )
    }

    func sendCartToOpenPixelmatorProject() {
        sendAssetsToPixelmator(
            cartAssets,
            preferSelectedVariant: false,
            documentSource: .openProject
        )
    }

    func sendCartToChosenPixelmatorDocument() {
        sendAssetsToPixelmator(
            cartAssets,
            preferSelectedVariant: false,
            documentSource: .chooseDocument
        )
    }

    func startPixelmatorProjectPolling() {
        stopPixelmatorProjectPolling()
        pixelmatorProjectPollingTask = Task { [weak self] in
            while !Task.isCancelled {
                let summary = await PixelmatorBridgeService.openProjectSummary()
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.applyPixelmatorSummary(summary)
                }
                try? await Task.sleep(nanoseconds: 4_000_000_000)
            }
        }
    }

    func stopPixelmatorProjectPolling() {
        pixelmatorProjectPollingTask?.cancel()
        pixelmatorProjectPollingTask = nil
        applyPixelmatorSummary(.empty)
    }

    func refreshPixelmatorProjectStatus() async {
        let summary = await PixelmatorBridgeService.openProjectSummary()
        applyPixelmatorSummary(summary)
    }
}

private enum PixelmatorDocumentSource {
    case openProject
    case chooseDocument
}

private extension AppModel {
    func applyPixelmatorSummary(_ summary: PixelmatorOpenProjectSummary) {
        pixelmatorOpenDocumentCount = summary.documentCount
        pixelmatorFrontDocumentPath = summary.frontDocumentPath
        pixelmatorFrontDocumentName = summary.frontDocumentName
    }

    func sendAssetsToPixelmator(
        _ assets: [DesignAsset],
        preferSelectedVariant: Bool,
        documentSource: PixelmatorDocumentSource
    ) {
        let payloads = assets.compactMap { asset in
            pixelmatorPayload(for: asset, preferSelectedVariant: preferSelectedVariant)
        }

        guard !payloads.isEmpty else {
            statusMessage = "Pick at least one asset before sending to Pixelmator."
            return
        }

        guard let pxdctlURL = resolvedPXDCTLURL() else {
            statusMessage = "Choose the pxdctl bridge tool before sending assets to Pixelmator."
            return
        }

        guard let documentURL = resolvedPixelmatorDocumentURL(source: documentSource) else {
            return
        }

        isSendingToPixelmator = true
        statusMessage = payloads.count == 1
            ? "Adding 1 asset to Pixelmator..."
            : "Adding \(payloads.count) assets to Pixelmator..."

        Task { [weak self] in
            do {
                let result = try await PixelmatorBridgeService.sendAssets(
                    payloads,
                    to: documentURL,
                    pxdctlURL: pxdctlURL
                )
                self?.recordPixelmatorSend(assetIDs: payloads.map(\.id))
                self?.statusMessage = "Added \(result.addedCount) asset\(result.addedCount == 1 ? "" : "s") to Pixelmator: \(result.documentURL.lastPathComponent)"
            } catch {
                self?.statusMessage = error.localizedDescription
            }
            self?.isSendingToPixelmator = false
            await self?.refreshPixelmatorProjectStatus()
        }
    }

    func recordPixelmatorSend(assetIDs: [String]) {
        for assetID in assetIDs {
            usedAssetIDs.insert(assetID)
            try? store?.recordUsage(assetID: assetID, event: "pixelmator")
        }
        refreshAfterCartChange()
    }

    func pixelmatorPayload(
        for asset: DesignAsset,
        preferSelectedVariant: Bool
    ) -> PixelmatorAssetPayload? {
        let variant = preferSelectedVariant && asset.id == selectedAssetID
            ? selectedVariant
            : asset.primaryVariant
        guard let variant else { return nil }

        let tags = asset.tags
            .map { "\($0.namespace):\($0.value)" }
            .sorted()

        return PixelmatorAssetPayload(
            id: asset.id,
            displayName: asset.displayName,
            kind: asset.kind,
            fileURL: variant.fileURL,
            tags: tags
        )
    }

    func resolvedPXDCTLURL() -> URL? {
        let candidates = [
            PixelmatorBridgeService.savedPXDCTLURL(),
            PixelmatorBridgeService.environmentPXDCTLURL(),
            PixelmatorBridgeService.pathPXDCTLURL(),
            PixelmatorBridgeService.bundledPXDCTLURL()
        ].compactMap(\.self)

        if let candidate = candidates.first(where: PixelmatorBridgeService.isExecutablePXDCTL) {
            PixelmatorBridgeService.savePXDCTLURL(candidate)
            return candidate
        }

        guard let chosen = choosePXDCTLURL() else { return nil }
        PixelmatorBridgeService.savePXDCTLURL(chosen)
        return chosen
    }

    func choosePXDCTLURL() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Choose pxdctl"
        panel.message = "Pick the Pixelmator bridge CLI. Crate stores this path for next time."
        panel.prompt = "Use pxdctl"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = PixelmatorBridgeService.savedPXDCTLURL()?.deletingLastPathComponent()
            ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        guard PixelmatorBridgeService.isExecutablePXDCTL(url) else {
            statusMessage = "\(url.lastPathComponent) is not executable. Pick the real pxdctl script."
            return nil
        }
        return url
    }

    func resolvedPixelmatorDocumentURL(source: PixelmatorDocumentSource) -> URL? {
        switch source {
        case .openProject:
            guard hasOpenPixelmatorProject else {
                statusMessage = "Open a Pixelmator project first, or choose a .pxd document."
                return nil
            }
            guard let url = pixelmatorFrontDocumentURL else {
                statusMessage = PixelmatorBridgeError.noOpenDocumentPath.localizedDescription
                return nil
            }
            PixelmatorBridgeService.saveTargetDocumentURL(url)
            return url
        case .chooseDocument:
            guard let url = choosePixelmatorDocumentURL() else { return nil }
            PixelmatorBridgeService.saveTargetDocumentURL(url)
            return url
        }
    }

    func choosePixelmatorDocumentURL() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Choose Pixelmator Project"
        panel.message = "Pick the .pxd document that should receive the selected Crate assets."
        panel.prompt = "Add Here"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = PixelmatorBridgeService.savedTargetDocumentURL()?.deletingLastPathComponent()
            ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        if let pxdType = UTType(filenameExtension: "pxd") {
            panel.allowedContentTypes = [pxdType]
        }

        return panel.runModal() == .OK ? panel.url : nil
    }
}
