//
//  DuplicateDetectionService.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import AppKit
import CryptoKit
import Foundation
import ImageIO

enum DuplicateDetectionService {
    static func scan(assets: [DesignAsset], nearThreshold: Int = 4) -> DuplicateReport {
        let fingerprints = assets.flatMap { asset in
            asset.variants.compactMap { variant in
                VariantFingerprint(asset: asset, variant: variant)
            }
        }

        return DuplicateReport(
            scannedAt: Date(),
            scannedVariantCount: fingerprints.count,
            exactFileGroups: exactFileGroups(from: fingerprints),
            sameImageGroups: sameImageGroups(from: fingerprints),
            jpgPngVariantGroups: jpgPngVariantGroups(from: fingerprints),
            nearDuplicateGroups: nearDuplicateGroups(from: primaryFingerprints(from: fingerprints), threshold: nearThreshold)
        )
    }

    private static func exactFileGroups(from fingerprints: [VariantFingerprint]) -> [DuplicateCluster] {
        let candidates = Dictionary(grouping: fingerprints, by: \.byteCount)
            .values
            .filter { Set($0.map(\.assetID)).count > 1 }

        let hashedGroups = candidates.flatMap { group in
            Dictionary(grouping: group.compactMap { fingerprint -> (String, VariantFingerprint)? in
                guard let hash = fingerprint.byteHash() else { return nil }
                return (hash, fingerprint)
            }, by: \.0).values.map { values in values.map(\.1) }
        }

        return hashedGroups
            .filter { Set($0.map(\.assetID)).count > 1 }
            .sorted { $0.first?.assetID ?? "" < $1.first?.assetID ?? "" }
            .map { group in
                DuplicateCluster(
                    id: "exact-\(group.first?.byteHash() ?? UUID().uuidString)",
                    title: "Exact file duplicate",
                    reason: .exactFile,
                    assetIDs: uniqueSorted(group.map(\.assetID)),
                    variantIDs: uniqueSorted(group.map(\.variantID)),
                    distance: nil
                )
            }
    }

    private static func sameImageGroups(from fingerprints: [VariantFingerprint]) -> [DuplicateCluster] {
        Dictionary(grouping: fingerprints.filter { !$0.isLowInformationVisualHash }, by: \.visualIdentityKey)
            .values
            .filter { Set($0.map(\.assetID)).count > 1 }
            .sorted { $0.first?.assetID ?? "" < $1.first?.assetID ?? "" }
            .map { group in
                let identityKey = group.first?.visualIdentityKey ?? UUID().uuidString
                return DuplicateCluster(
                    id: "same-\(identityKey)",
                    title: "Same visual image",
                    reason: .sameImage,
                    assetIDs: uniqueSorted(group.map(\.assetID)),
                    variantIDs: uniqueSorted(group.map(\.variantID)),
                    distance: 0
                )
            }
    }

    private static func jpgPngVariantGroups(from fingerprints: [VariantFingerprint]) -> [DuplicateCluster] {
        Dictionary(grouping: fingerprints, by: \.variantFamilyKey)
            .values
            .filter { group in
                let extensions = Set(group.map(\.fileExtension))
                return group.count > 1 && extensions.contains("png") && !extensions.isDisjoint(with: ["jpg", "jpeg"])
            }
            .sorted { $0.first?.variantFamilyKey ?? "" < $1.first?.variantFamilyKey ?? "" }
            .map { group in
                DuplicateCluster(
                    id: "variant-\(group.first?.variantFamilyKey ?? UUID().uuidString)",
                    title: "JPG/PNG variants",
                    reason: .jpgPngVariant,
                    assetIDs: uniqueSorted(group.map(\.assetID)),
                    variantIDs: uniqueSorted(group.map(\.variantID)),
                    distance: nil
                )
            }
    }

    private static func nearDuplicateGroups(from fingerprints: [VariantFingerprint], threshold: Int) -> [DuplicateCluster] {
        guard fingerprints.count > 1 else { return [] }
        let fingerprints = fingerprints.filter { !$0.isLowInformationVisualHash }
        var unionFind = UnionFind(values: fingerprints.map(\.assetID))
        var minimumDistanceByPair: [String: Int] = [:]

        for leftIndex in fingerprints.indices {
            for rightIndex in fingerprints.index(after: leftIndex)..<fingerprints.endIndex {
                let left = fingerprints[leftIndex]
                let right = fingerprints[rightIndex]
                guard left.assetID != right.assetID else { continue }
                guard left.assetKind == right.assetKind else { continue }
                guard left.aspectDelta(to: right) <= 0.08 else { continue }
                let distance = hammingDistance(left.visualHash, right.visualHash)
                guard distance > 0, distance <= threshold else { continue }
                unionFind.union(left.assetID, right.assetID)
                let key = [left.assetID, right.assetID].sorted().joined(separator: "|")
                minimumDistanceByPair[key] = min(minimumDistanceByPair[key] ?? distance, distance)
            }
        }

        return unionFind.groups()
            .filter { $0.count > 1 }
            .sorted { ($0.first ?? "") < ($1.first ?? "") }
            .map { assetIDs in
                let distances = minimumDistanceByPair
                    .filter { key, _ in
                        let parts = key.split(separator: "|").map(String.init)
                        return parts.allSatisfy { assetIDs.contains($0) }
                    }
                    .map(\.value)
                let minDistance = distances.min()
                return DuplicateCluster(
                    id: "near-\(assetIDs.joined(separator: "-"))",
                    title: "Near duplicate",
                    reason: .nearDuplicate,
                    assetIDs: assetIDs,
                    variantIDs: fingerprints.filter { assetIDs.contains($0.assetID) }.map(\.variantID).sorted(),
                    distance: minDistance
                )
            }
    }

    private static func primaryFingerprints(from fingerprints: [VariantFingerprint]) -> [VariantFingerprint] {
        let grouped = Dictionary(grouping: fingerprints) { fingerprint in
            fingerprint.assetID
        }
        return grouped.values
            .compactMap { group -> VariantFingerprint? in
                group.first(where: { $0.role == .transparent })
                    ?? group.first(where: { $0.role == .original })
                    ?? group.first
            }
            .sorted { $0.assetID < $1.assetID }
    }

    private static func uniqueSorted(_ values: [String]) -> [String] {
        Array(Set(values)).sorted()
    }

    private static func hammingDistance(_ lhs: UInt64, _ rhs: UInt64) -> Int {
        (lhs ^ rhs).nonzeroBitCount
    }
}

private struct VariantFingerprint {
    let assetID: String
    let assetKind: String
    let variantID: String
    let role: AssetVariantRole
    let fileURL: URL
    let fileExtension: String
    let variantFamilyKey: String
    let width: Int
    let height: Int
    let byteCount: Int64
    let visualHash: UInt64

    var visualIdentityKey: String {
        "\(width)x\(height)-\(String(visualHash, radix: 16))"
    }

    var isLowInformationVisualHash: Bool {
        visualHash.nonzeroBitCount <= 2 || visualHash.nonzeroBitCount >= 62
    }

    init?(asset: DesignAsset, variant: AssetVariant) {
        guard FileManager.default.fileExists(atPath: variant.fileURL.path),
              let visualHash = Self.visualHash(url: asset.thumbnailURL ?? variant.fileURL)
        else { return nil }

        assetID = asset.id
        assetKind = asset.kind
        variantID = variant.id
        role = variant.role
        fileURL = variant.fileURL
        fileExtension = variant.fileExtension.lowercased()
        variantFamilyKey = Self.variantFamilyKey(url: variant.fileURL)
        width = variant.width
        height = variant.height
        byteCount = variant.byteCount
        self.visualHash = visualHash
    }

    func aspectDelta(to other: VariantFingerprint) -> Double {
        let lhs = Double(width) / Double(max(height, 1))
        let rhs = Double(other.width) / Double(max(other.height, 1))
        return abs(lhs - rhs)
    }

    func byteHash() -> String? {
        Self.sha256(url: fileURL)
    }

    private static func sha256(url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let data = handle.readData(ofLength: 1024 * 1024)
            guard !data.isEmpty else { return false }
            hasher.update(data: data)
            return true
        }) {}

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func visualHash(url: URL) -> UInt64? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 64
        ] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }

        let width = 8
        let height = 8
        var pixels = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        context.interpolationQuality = .low
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let average = pixels.reduce(0) { $0 + Int($1) } / max(pixels.count, 1)
        return pixels.enumerated().reduce(UInt64(0)) { result, item in
            let (index, pixel) = item
            guard Int(pixel) >= average else { return result }
            return result | (UInt64(1) << UInt64(index))
        }
    }

    private static func variantFamilyKey(url: URL) -> String {
        var stem = url.deletingPathExtension().lastPathComponent.lowercased()
        for suffix in [".transparent", ".flat", ".original", ".preview"] where stem.hasSuffix(suffix) {
            stem.removeLast(suffix.count)
            break
        }
        return stem
    }
}

private struct UnionFind {
    private var parent: [String: String]

    init(values: [String]) {
        parent = Dictionary(uniqueKeysWithValues: values.map { ($0, $0) })
    }

    mutating func union(_ lhs: String, _ rhs: String) {
        let leftRoot = find(lhs)
        let rightRoot = find(rhs)
        guard leftRoot != rightRoot else { return }
        parent[rightRoot] = leftRoot
    }

    mutating func groups() -> [[String]] {
        for key in parent.keys {
            _ = find(key)
        }
        return Dictionary(grouping: parent.keys, by: { parent[$0] ?? $0 })
            .values
            .map { $0.sorted() }
    }

    private mutating func find(_ value: String) -> String {
        let root = parent[value] ?? value
        guard root != value else { return root }
        let compressed = find(root)
        parent[value] = compressed
        return compressed
    }
}
