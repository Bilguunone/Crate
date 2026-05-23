//
//  ImageDataCache.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import Foundation
import ImageIO
import UniformTypeIdentifiers

actor ImageDataCache {
    private var values: [String: Data] = [:]
    private var costs: [String: Int] = [:]
    private var order: [String] = []
    private var totalCost = 0

    private let countLimit: Int
    private let totalCostLimit: Int

    init(countLimit: Int, totalCostLimit: Int) {
        self.countLimit = countLimit
        self.totalCostLimit = totalCostLimit
    }

    func value(for key: String) -> Data? {
        values[key]
    }

    func insert(_ data: Data, for key: String) {
        if values[key] == nil {
            order.append(key)
        } else {
            totalCost -= costs[key] ?? 0
        }

        values[key] = data
        costs[key] = data.count
        totalCost += data.count
        trimIfNeeded()
    }

    private func trimIfNeeded() {
        while values.count > countLimit || totalCost > totalCostLimit {
            guard let key = order.first else { return }
            order.removeFirst()
            totalCost -= costs[key] ?? 0
            values[key] = nil
            costs[key] = nil
        }
    }
}

enum ImageDownsampler {
    private static let thumbnailCache = ImageDataCache(
        countLimit: 1_200,
        totalCostLimit: 180 * 1_024 * 1_024
    )
    private static let previewCache = ImageDataCache(
        countLimit: 80,
        totalCostLimit: 320 * 1_024 * 1_024
    )

    static func thumbnailData(for url: URL) async -> Data? {
        await imageData(for: url, label: "image.thumbnail", maxPixelSize: 520, cache: thumbnailCache)
    }

    static func previewData(for url: URL) async -> Data? {
        await imageData(for: url, label: "image.preview", maxPixelSize: 1_800, cache: previewCache)
    }

    private static func imageData(
        for url: URL,
        label: String,
        maxPixelSize: Int,
        cache: ImageDataCache
    ) async -> Data? {
        let key = cacheKey(for: url, maxPixelSize: maxPixelSize)
        if let cachedData = await cache.value(for: key) {
            CrateTelemetry.images.trace("\(label, privacy: .public) cache hit")
            return cachedData
        }

        let data = await CrateTelemetry.measureAsync("\(label).decode", details: "px=\(maxPixelSize)") {
            await Task.detached(priority: .utility) {
                downsampledPNGData(for: url, maxPixelSize: maxPixelSize)
            }.value
        }

        if let data {
            await cache.insert(data, for: key)
        }
        return data
    }

    private static func downsampledPNGData(for url: URL, maxPixelSize: Int) -> Data? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldCacheImmediately: true
        ]

        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    private static func cacheKey(for url: URL, maxPixelSize: Int) -> String {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let modified = values?.contentModificationDate?.timeIntervalSince1970 ?? 0
        let fileSize = values?.fileSize ?? 0
        return "\(maxPixelSize)|\(url.standardizedFileURL.path)|\(modified)|\(fileSize)"
    }
}
