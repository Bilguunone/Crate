//
//  ImageMetadata.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-22.
//

import AppKit
import Foundation
import ImageIO

struct ImageMetadata: Hashable {
    var width: Int
    var height: Int
    var hasAlpha: Bool
    var byteCount: Int64
}

enum ImageMetadataReader {
    static func read(_ url: URL) -> ImageMetadata? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { return nil }

        let width = properties[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties[kCGImagePropertyPixelHeight] as? Int ?? 0
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let byteCount = (attributes?[.size] as? NSNumber)?.int64Value ?? 0

        var hasAlpha = false
        if let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            switch image.alphaInfo {
            case .first, .last, .premultipliedFirst, .premultipliedLast:
                hasAlpha = true
            default:
                hasAlpha = false
            }
        }

        return ImageMetadata(width: width, height: height, hasAlpha: hasAlpha, byteCount: byteCount)
    }
}
