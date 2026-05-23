//
//  PixelmatorBridgeService.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-24.
//

import Foundation

enum PixelmatorBridgeError: LocalizedError {
    case pxdctlUnavailable
    case noAssets
    case noOpenDocumentPath
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .pxdctlUnavailable:
            "Choose the pxdctl bridge tool before sending assets to Pixelmator."
        case .noAssets:
            "Pick at least one asset before sending to Pixelmator."
        case .noOpenDocumentPath:
            "Pixelmator has a project open, but Crate cannot see a saved .pxd path. Save the project first, then try again."
        case .commandFailed(let message):
            message.isEmpty ? "Pixelmator bridge failed." : message
        }
    }
}

struct PixelmatorOpenProjectSummary: Equatable, Sendable {
    var documentCount: Int
    var frontDocumentPath: String?
    var frontDocumentName: String?

    static let empty = PixelmatorOpenProjectSummary(
        documentCount: 0,
        frontDocumentPath: nil,
        frontDocumentName: nil
    )
}

struct PixelmatorAssetPayload: Equatable, Sendable {
    var id: String
    var displayName: String
    var kind: String
    var fileURL: URL
    var tags: [String]
}

struct PixelmatorSendResult: Equatable, Sendable {
    var documentURL: URL
    var addedCount: Int
}

enum PixelmatorBridgeService {
    static let pxdctlDefaultsKey = "crate.pixelmator.pxdctlPath"
    static let targetDocumentDefaultsKey = "crate.pixelmator.targetDocumentPath"

    static func savedPXDCTLURL() -> URL? {
        guard let path = UserDefaults.standard.string(forKey: pxdctlDefaultsKey), !path.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: path)
    }

    static func savePXDCTLURL(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: pxdctlDefaultsKey)
    }

    static func savedTargetDocumentURL() -> URL? {
        guard let path = UserDefaults.standard.string(forKey: targetDocumentDefaultsKey), !path.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: path)
    }

    static func saveTargetDocumentURL(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: targetDocumentDefaultsKey)
    }

    static func environmentPXDCTLURL() -> URL? {
        guard let path = ProcessInfo.processInfo.environment["CRATE_PXDCTL_PATH"], !path.isEmpty else {
            return nil
        }
        let expanded = (path as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expanded)
    }

    static func pathPXDCTLURL() -> URL? {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", "pxdctl"]
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        let path = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path)
    }

    static func bundledPXDCTLURL() -> URL? {
        guard let resourcesURL = Bundle.main.resourceURL else { return nil }
        let url = resourcesURL
            .appendingPathComponent("Pixelmator", isDirectory: true)
            .appendingPathComponent("pxdctl-crate-bridge")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static func isExecutablePXDCTL(_ url: URL) -> Bool {
        FileManager.default.isExecutableFile(atPath: url.path)
    }

    static func openProjectSummary() async -> PixelmatorOpenProjectSummary {
        await Task.detached(priority: .utility) {
            do {
                let output = try runProcess(
                    executableURL: URL(fileURLWithPath: "/usr/bin/osascript"),
                    arguments: [
                        "-e", "tell application id \"com.apple.pixelmator\"",
                        "-e", "if it is not running then return \"0\"",
                        "-e", "set documentCount to count of documents",
                        "-e", "if documentCount is 0 then return \"0\"",
                        "-e", "set documentPath to \"\"",
                        "-e", "set documentName to \"\"",
                        "-e", "try",
                        "-e", "set documentPath to POSIX path of (file of front document as alias)",
                        "-e", "end try",
                        "-e", "try",
                        "-e", "set documentName to name of front document",
                        "-e", "end try",
                        "-e", "return (documentCount as text) & linefeed & documentPath & linefeed & documentName",
                        "-e", "end tell"
                    ]
                )
                return parseOpenProjectSummary(output)
            } catch {
                return .empty
            }
        }.value
    }

    static func sendAssets(
        _ assets: [PixelmatorAssetPayload],
        to documentURL: URL,
        pxdctlURL: URL
    ) async throws -> PixelmatorSendResult {
        guard !assets.isEmpty else { throw PixelmatorBridgeError.noAssets }
        guard isExecutablePXDCTL(pxdctlURL) else { throw PixelmatorBridgeError.pxdctlUnavailable }

        let spec = applySpec(documentURL: documentURL, assets: assets)
        let specURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("crate-pixelmator-\(UUID().uuidString).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(spec)

        return try await Task.detached(priority: .userInitiated) {
            try data.write(to: specURL, options: .atomic)
            defer { try? FileManager.default.removeItem(at: specURL) }

            _ = try runProcess(
                executableURL: pxdctlURL,
                arguments: ["apply", documentURL.path, specURL.path]
            )
            return PixelmatorSendResult(documentURL: documentURL, addedCount: assets.count)
        }.value
    }

    static func applySpec(documentURL: URL, assets: [PixelmatorAssetPayload]) -> PixelmatorApplySpec {
        PixelmatorApplySpec(
            document: documentURL.path,
            description: "Add \(assets.count) Crate asset\(assets.count == 1 ? "" : "s") to Pixelmator",
            openDelay: 0.6,
            save: false,
            edits: assets.map { asset in
                PixelmatorImageEdit(
                    name: "Crate: \(asset.displayName)",
                    path: asset.fileURL.path,
                    crateAsset: PixelmatorCrateAssetMetadata(
                        id: asset.id,
                        kind: asset.kind,
                        tags: asset.tags
                    )
                )
            }
        )
    }
}

struct PixelmatorApplySpec: Codable, Equatable, Sendable {
    var document: String
    var description: String
    var openDelay: Double
    var save: Bool
    var edits: [PixelmatorImageEdit]
}

struct PixelmatorImageEdit: Codable, Equatable, Sendable {
    var op = "add-image"
    var name: String
    var path: String
    var opacity = 100
    var blendMode = "normal"
    var at = "beginning"
    var constrainProportions = true
    var preserveTransparency = true
    var crateAsset: PixelmatorCrateAssetMetadata
}

struct PixelmatorCrateAssetMetadata: Codable, Equatable, Sendable {
    var id: String
    var kind: String
    var tags: [String]
}

private func parseOpenProjectSummary(_ output: String) -> PixelmatorOpenProjectSummary {
    let lines = output
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map(String.init)
    guard let firstLine = lines.first,
          let count = Int(firstLine.trimmingCharacters(in: .whitespacesAndNewlines)),
          count > 0
    else {
        return .empty
    }

    let path = lines.dropFirst().first?.trimmingCharacters(in: .whitespacesAndNewlines)
    let name = lines.dropFirst(2).first?.trimmingCharacters(in: .whitespacesAndNewlines)
    return PixelmatorOpenProjectSummary(
        documentCount: count,
        frontDocumentPath: path?.isEmpty == false ? path : nil,
        frontDocumentName: name?.isEmpty == false ? name : nil
    )
}

private func runProcess(executableURL: URL, arguments: [String]) throws -> String {
    let process = Process()
    let output = Pipe()
    let error = Pipe()
    process.executableURL = executableURL
    process.arguments = arguments
    process.standardOutput = output
    process.standardError = error

    try process.run()
    process.waitUntilExit()

    let stdout = String(
        decoding: output.fileHandleForReading.readDataToEndOfFile(),
        as: UTF8.self
    )
    let stderr = String(
        decoding: error.fileHandleForReading.readDataToEndOfFile(),
        as: UTF8.self
    )

    guard process.terminationStatus == 0 else {
        let message = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        throw PixelmatorBridgeError.commandFailed(message)
    }

    return stdout.trimmingCharacters(in: .whitespacesAndNewlines)
}
