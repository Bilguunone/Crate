//
//  VisualAnalysisService.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import CoreGraphics
import Foundation
import ImageIO

enum VisualAnalysisService {
    static func computedTags(for asset: DesignAsset) -> [AssetTag] {
        guard let variant = asset.primaryVariant else { return [] }
        let analysisURL = variant.hasAlpha ? variant.fileURL : (asset.thumbnailURL ?? variant.fileURL)
        return computedTags(for: variant, imageURL: analysisURL, assetKind: asset.kind)
    }

    static func computedTags(for variant: AssetVariant) -> [AssetTag] {
        computedTags(for: variant, imageURL: variant.fileURL, assetKind: nil)
    }

    static func computedTags(for variant: AssetVariant, assetKind: String?) -> [AssetTag] {
        computedTags(for: variant, imageURL: variant.fileURL, assetKind: assetKind)
    }

    private static func computedTags(for variant: AssetVariant, imageURL: URL, assetKind: String?) -> [AssetTag] {
        guard let analysis = analyze(url: imageURL, width: variant.width, height: variant.height) else {
            return [orientationTag(width: variant.width, height: variant.height)] + metadataQualityTags(for: variant)
        }
        return analysis.tags + qualityTags(for: variant, assetKind: assetKind, analysis: analysis)
    }

    static func tagUpdates(for assets: [DesignAsset]) -> VisualAnalysisReport {
        var updates: [String: [AssetTag]] = [:]
        var failed = 0

        for asset in assets {
            let tags = computedTags(for: asset)
            if tags.isEmpty {
                failed += 1
            } else {
                updates[asset.id] = tags
            }
        }

        return VisualAnalysisReport(
            analyzedAssetCount: updates.count,
            failedAssetCount: failed,
            writtenTagCount: updates.values.reduce(0) { $0 + $1.count },
            updates: updates
        )
    }

    private static func analyze(url: URL, width originalWidth: Int, height originalHeight: Int) -> VisualAnalysisResult? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 96
        ] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }

        let width = 64
        let height = 64
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var colorWeights: [String: Double] = [:]
        var lumaValues = [Double](repeating: 0, count: width * height)
        var visibleWeight = 0.0
        var weightedLumaSum = 0.0
        var transparentPixels = 0
        var semiTransparentPixels = 0
        var whiteFringePixels = 0
        var borderPixels = 0
        var borderWhitePixels = 0
        var centerPixels = 0
        var centerNonWhitePixels = 0
        let borderInset = 6
        let centerInset = 16

        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let offset = index * 4
                let alpha = Double(pixels[offset + 3]) / 255.0
                if alpha < 0.98 {
                    transparentPixels += 1
                }
                if alpha > 0.04 && alpha < 0.96 {
                    semiTransparentPixels += 1
                }
                guard alpha > 0.04 else { continue }

                let red = unpremultiply(pixels[offset], alpha: pixels[offset + 3])
                let green = unpremultiply(pixels[offset + 1], alpha: pixels[offset + 3])
                let blue = unpremultiply(pixels[offset + 2], alpha: pixels[offset + 3])
                let nearWhite = isNearWhite(red: red, green: green, blue: blue)
                if alpha < 0.96, nearWhite {
                    whiteFringePixels += 1
                }
                if x < borderInset || y < borderInset || x >= width - borderInset || y >= height - borderInset {
                    borderPixels += 1
                    if alpha > 0.92, nearWhite {
                        borderWhitePixels += 1
                    }
                }
                if x >= centerInset && y >= centerInset && x < width - centerInset && y < height - centerInset {
                    centerPixels += 1
                    if alpha > 0.72, !nearWhite {
                        centerNonWhitePixels += 1
                    }
                }
                let luma = 0.2126 * red + 0.7152 * green + 0.0722 * blue
                lumaValues[index] = luma
                visibleWeight += alpha
                weightedLumaSum += luma * alpha
                colorWeights[colorBucket(red: red, green: green, blue: blue), default: 0] += alpha
            }
        }

        guard visibleWeight > 0 else {
            return VisualAnalysisResult(tags: [
                tag("transparency", "full"),
                orientationTag(width: originalWidth, height: originalHeight),
                tag("brightness", "dark"),
                tag("contrast", "low"),
                tag("edge_density", "soft")
            ], qualityMetrics: .empty)
        }

        let averageLuma = weightedLumaSum / visibleWeight
        let contrast = contrastScore(lumaValues: lumaValues, average: averageLuma)
        let transparencyRatio = Double(transparentPixels) / Double(max(width * height, 1))
        let edgeDensity = edgeDensityScore(lumaValues: lumaValues, width: width, height: height)
        let semiTransparentRatio = Double(semiTransparentPixels) / Double(max(width * height, 1))
        let whiteFringeRatio = Double(whiteFringePixels) / Double(max(semiTransparentPixels, 1))
        let borderWhiteRatio = Double(borderWhitePixels) / Double(max(borderPixels, 1))
        let centerNonWhiteRatio = Double(centerNonWhitePixels) / Double(max(centerPixels, 1))
        let dominantWhiteShare = (colorWeights["white"] ?? 0) / visibleWeight
        let dominantColors = colorWeights
            .sorted { lhs, rhs in lhs.value == rhs.value ? lhs.key < rhs.key : lhs.value > rhs.value }
            .prefix(3)
            .filter { $0.value / visibleWeight >= 0.08 }

        var tags = dominantColors.map { color, weight in
            tag("color", color, confidence: min(1, max(0.35, weight / visibleWeight)))
        }
        tags.append(tag("brightness", brightnessBucket(averageLuma)))
        tags.append(tag("contrast", contrastBucket(contrast)))
        tags.append(orientationTag(width: originalWidth, height: originalHeight))
        tags.append(tag("transparency", transparencyBucket(transparencyRatio)))
        tags.append(tag("edge_density", edgeDensityBucket(edgeDensity)))
        return VisualAnalysisResult(
            tags: tags,
            qualityMetrics: VisualQualityMetrics(
                contrast: contrast,
                transparencyRatio: transparencyRatio,
                edgeDensity: edgeDensity,
                semiTransparentRatio: semiTransparentRatio,
                whiteFringeRatio: whiteFringeRatio,
                borderWhiteRatio: borderWhiteRatio,
                centerNonWhiteRatio: centerNonWhiteRatio,
                dominantWhiteShare: dominantWhiteShare
            )
        )
    }

    private static func metadataQualityTags(for variant: AssetVariant) -> [AssetTag] {
        var tags: [AssetTag] = []
        appendResolutionWarnings(for: variant, to: &tags)
        return tags
    }

    private static func qualityTags(for variant: AssetVariant, assetKind: String?, analysis: VisualAnalysisResult) -> [AssetTag] {
        var tags: [AssetTag] = []
        let metrics = analysis.qualityMetrics
        appendResolutionWarnings(for: variant, to: &tags)

        if variant.hasAlpha, metrics.transparencyRatio < 0.003 {
            tags.append(tag("quality", "fake-transparency", confidence: 0.9))
        }

        if assetKind != "texture",
           (variant.fileExtension.lowercased() == "png" || variant.hasAlpha),
           metrics.transparencyRatio < 0.03,
           metrics.borderWhiteRatio > 0.86,
           metrics.centerNonWhiteRatio > 0.08 {
            tags.append(tag("quality", "white-boxed-background", confidence: 0.82))
        }

        if variant.hasAlpha,
           metrics.transparencyRatio > 0.02,
           metrics.semiTransparentRatio > 0.008,
           metrics.whiteFringeRatio > 0.35,
           metrics.dominantWhiteShare < 0.55 {
            tags.append(tag("quality", "bad-alpha-edges", confidence: 0.72))
        }

        if min(variant.width, variant.height) >= 900,
           metrics.edgeDensity < 0.01,
           metrics.contrast > 0.025,
           metrics.contrast < 0.07,
           metrics.dominantWhiteShare < 0.75 {
            tags.append(tag("quality", "blurry", confidence: 0.68))
        }

        return tags
    }

    private static func appendResolutionWarnings(for variant: AssetVariant, to tags: inout [AssetTag]) {
        let minDimension = min(variant.width, variant.height)
        let pixelCount = variant.width * variant.height
        if minDimension < 512 || pixelCount < 512 * 512 {
            tags.append(tag("quality", "low-resolution", confidence: minDimension < 256 ? 0.95 : 0.78))
        }

        let megapixels = Double(max(pixelCount, 1)) / 1_000_000
        let bytesPerMegapixel = Double(variant.byteCount) / max(megapixels, 0.1)
        if variant.byteCount >= 40 * 1024 * 1024 || (variant.byteCount >= 16 * 1024 * 1024 && bytesPerMegapixel > 24 * 1024 * 1024) {
            tags.append(tag("quality", "giant-file", confidence: 0.86))
        }
    }

    private static func unpremultiply(_ component: UInt8, alpha: UInt8) -> Double {
        guard alpha > 0 else { return 0 }
        return min(1, Double(component) / Double(alpha))
    }

    private static func isNearWhite(red: Double, green: Double, blue: Double) -> Bool {
        min(red, green, blue) > 0.86 && max(red, green, blue) - min(red, green, blue) < 0.12
    }

    private static func contrastScore(lumaValues: [Double], average: Double) -> Double {
        let variance = lumaValues.reduce(0) { partial, luma in
            let delta = luma - average
            return partial + delta * delta
        } / Double(max(lumaValues.count, 1))
        return sqrt(variance)
    }

    private static func edgeDensityScore(lumaValues: [Double], width: Int, height: Int) -> Double {
        guard width > 2, height > 2 else { return 0 }
        var edgeCount = 0
        var sampled = 0

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let left = lumaValues[y * width + (x - 1)]
                let right = lumaValues[y * width + (x + 1)]
                let top = lumaValues[(y - 1) * width + x]
                let bottom = lumaValues[(y + 1) * width + x]
                let gradient = abs(right - left) + abs(bottom - top)
                if gradient > 0.26 {
                    edgeCount += 1
                }
                sampled += 1
            }
        }

        return Double(edgeCount) / Double(max(sampled, 1))
    }

    private static func colorBucket(red: Double, green: Double, blue: Double) -> String {
        let maxValue = max(red, green, blue)
        let minValue = min(red, green, blue)
        let delta = maxValue - minValue
        let saturation = maxValue == 0 ? 0 : delta / maxValue

        if saturation < 0.14 {
            if maxValue < 0.18 { return "black" }
            if maxValue > 0.84 { return "white" }
            return "gray"
        }

        let hue: Double
        if maxValue == red {
            hue = 60 * ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
        } else if maxValue == green {
            hue = 60 * (((blue - red) / delta) + 2)
        } else {
            hue = 60 * (((red - green) / delta) + 4)
        }

        let normalizedHue = hue < 0 ? hue + 360 : hue
        switch normalizedHue {
        case 0..<18, 345...360:
            return "red"
        case 18..<45:
            return "orange"
        case 45..<75:
            return "yellow"
        case 75..<165:
            return "green"
        case 165..<200:
            return "cyan"
        case 200..<250:
            return "blue"
        case 250..<290:
            return "purple"
        default:
            return "pink"
        }
    }

    private static func brightnessBucket(_ value: Double) -> String {
        if value < 0.33 { return "dark" }
        if value < 0.68 { return "medium" }
        return "bright"
    }

    private static func contrastBucket(_ value: Double) -> String {
        if value < 0.16 { return "low" }
        if value < 0.32 { return "medium" }
        return "high"
    }

    private static func transparencyBucket(_ value: Double) -> String {
        if value < 0.01 { return "none" }
        if value < 0.25 { return "light" }
        if value < 0.65 { return "partial" }
        return "heavy"
    }

    private static func edgeDensityBucket(_ value: Double) -> String {
        if value < 0.08 { return "soft" }
        if value < 0.22 { return "moderate" }
        return "busy"
    }

    private static func orientationTag(width: Int, height: Int) -> AssetTag {
        let ratio = Double(max(width, 1)) / Double(max(height, 1))
        let value: String
        if ratio >= 2 {
            value = "panoramic"
        } else if ratio <= 0.5 {
            value = "tall"
        } else if ratio > 1.12 {
            value = "landscape"
        } else if ratio < 0.88 {
            value = "portrait"
        } else {
            value = "square"
        }
        return tag("orientation", value)
    }

    private static func tag(_ namespace: String, _ value: String, confidence: Double = 0.9) -> AssetTag {
        AssetTag(namespace: namespace, value: value, source: "computed", confidence: confidence, protected: false)
    }
}

struct VisualAnalysisReport: Encodable {
    let analyzedAssetCount: Int
    let failedAssetCount: Int
    let writtenTagCount: Int

    var updates: [String: [AssetTag]]

    enum CodingKeys: String, CodingKey {
        case analyzedAssetCount
        case failedAssetCount
        case writtenTagCount
    }
}

private struct VisualAnalysisResult {
    let tags: [AssetTag]
    let qualityMetrics: VisualQualityMetrics
}

private struct VisualQualityMetrics {
    let contrast: Double
    let transparencyRatio: Double
    let edgeDensity: Double
    let semiTransparentRatio: Double
    let whiteFringeRatio: Double
    let borderWhiteRatio: Double
    let centerNonWhiteRatio: Double
    let dominantWhiteShare: Double

    static let empty = VisualQualityMetrics(
        contrast: 0,
        transparencyRatio: 1,
        edgeDensity: 0,
        semiTransparentRatio: 0,
        whiteFringeRatio: 0,
        borderWhiteRatio: 0,
        centerNonWhiteRatio: 0,
        dominantWhiteShare: 0
    )
}
