//
//  VisualAnalysisQualityTests.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-24.
//

import CoreGraphics
import Foundation
import ImageIO
import XCTest
@testable import Crate

final class VisualAnalysisQualityTests: XCTestCase {
    private var temporaryRoot: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("crate-quality-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryRoot {
            try? FileManager.default.removeItem(at: temporaryRoot)
        }
        try super.tearDownWithError()
    }

    func testFlagsFakeTransparencyLowResolutionAndGiantFiles() throws {
        let url = try writePNG(name: "fake-alpha.png", width: 64, height: 64) { _, _ in
            Pixel(red: 220, green: 20, blue: 20, alpha: 255)
        }
        let asset = makeAsset(
            id: "fake-alpha",
            kind: "sticker",
            url: url,
            width: 64,
            height: 64,
            hasAlpha: true,
            byteCount: 48 * 1024 * 1024
        )

        let qualityValues = qualityValues(for: asset)

        XCTAssertTrue(qualityValues.contains("fake-transparency"))
        XCTAssertTrue(qualityValues.contains("low-resolution"))
        XCTAssertTrue(qualityValues.contains("giant-file"))
    }

    func testFlagsWhiteBoxedStickerBackgrounds() throws {
        let url = try writePNG(name: "boxed.png", width: 768, height: 768) { x, y in
            if x > 192 && x < 576 && y > 192 && y < 576 {
                return Pixel(red: 20, green: 20, blue: 20, alpha: 255)
            }
            return Pixel(red: 255, green: 255, blue: 255, alpha: 255)
        }
        let asset = makeAsset(id: "boxed", kind: "sticker", url: url, width: 768, height: 768, hasAlpha: false)

        XCTAssertTrue(qualityValues(for: asset).contains("white-boxed-background"))
    }

    func testFlagsBadAlphaEdges() throws {
        let center = 512
        let url = try writePNG(name: "halo.png", width: 1024, height: 1024) { x, y in
            let dx = abs(x - center)
            let dy = abs(y - center)
            if dx < 240 && dy < 240 {
                return Pixel(red: 20, green: 20, blue: 20, alpha: 255)
            }
            if dx < 280 && dy < 280 {
                return Pixel(red: 255, green: 255, blue: 255, alpha: 128)
            }
            return Pixel(red: 0, green: 0, blue: 0, alpha: 0)
        }
        let asset = makeAsset(id: "halo", kind: "sticker", url: url, width: 1024, height: 1024, hasAlpha: true)

        XCTAssertTrue(qualityValues(for: asset).contains("bad-alpha-edges"))
    }

    func testFlagsBlurrySoftLargeAssets() throws {
        let url = try writePNG(name: "soft.png", width: 1024, height: 1024) { x, _ in
            let value = UInt8(116 + (x * 24 / 1023))
            return Pixel(red: value, green: value, blue: value, alpha: 255)
        }
        let asset = makeAsset(id: "soft", kind: "overlay", url: url, width: 1024, height: 1024, hasAlpha: false)

        XCTAssertTrue(qualityValues(for: asset).contains("blurry"))
    }

    private func qualityValues(for asset: DesignAsset) -> Set<String> {
        Set(VisualAnalysisService.computedTags(for: asset)
            .filter { $0.namespace == "quality" }
            .map(\.value))
    }

    private func makeAsset(
        id: String,
        kind: String,
        url: URL,
        width: Int,
        height: Int,
        hasAlpha: Bool,
        byteCount: Int64 = 1024
    ) -> DesignAsset {
        let variant = AssetVariant(
            id: "\(id)-original",
            assetID: id,
            role: .original,
            fileURL: url,
            originalFileName: url.lastPathComponent,
            fileExtension: "png",
            width: width,
            height: height,
            hasAlpha: hasAlpha,
            byteCount: byteCount
        )
        return DesignAsset(
            id: id,
            packID: "test-pack",
            displayName: id,
            normalizedName: id,
            primaryVariantID: variant.id,
            kind: kind,
            createdAt: Date(timeIntervalSince1970: 1),
            variants: [variant],
            tags: [],
            thumbnailURL: nil
        )
    }

    private func writePNG(name: String, width: Int, height: Int, pixel: (Int, Int) -> Pixel) throws -> URL {
        let url = temporaryRoot.appendingPathComponent(name)
        var pixels: [UInt8] = []
        pixels.reserveCapacity(width * height * 4)

        for y in 0..<height {
            for x in 0..<width {
                let value = pixel(x, y)
                pixels.append(value.red)
                pixels.append(value.green)
                pixels.append(value.blue)
                pixels.append(value.alpha)
            }
        }

        let provider = CGDataProvider(data: Data(pixels) as CFData)
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.last.rawValue
        guard let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
            provider: provider!,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            throw QualityTestError.imageCreationFailed
        }

        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
            throw QualityTestError.destinationCreationFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw QualityTestError.writeFailed
        }
        return url
    }
}

private struct Pixel {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let alpha: UInt8
}

private enum QualityTestError: Error {
    case imageCreationFailed
    case destinationCreationFailed
    case writeFailed
}
