//
//  ThumbnailService.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-22.
//

import AppKit
import Foundation
import ImageIO

enum ThumbnailService {
    static func thumbnailURL(for assetID: String, in paths: LibraryPaths, preservesAlpha: Bool) -> URL {
        paths.thumbnails.appendingPathComponent("\(assetID).\(preservesAlpha ? "png" : "jpg")")
    }

    static func generateThumbnail(
        sourceURL: URL,
        assetID: String,
        paths: LibraryPaths,
        preservesAlpha: Bool,
        maxPixelSize: Int = 420
    ) throws -> URL? {
        let destinationURL = thumbnailURL(for: assetID, in: paths, preservesAlpha: preservesAlpha)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            return destinationURL
        }

        guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else { return nil }

        let typeIdentifier = preservesAlpha ? "public.png" : "public.jpeg"
        guard let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, typeIdentifier as CFString, 1, nil) else {
            return nil
        }
        let properties: CFDictionary? = preservesAlpha
            ? nil
            : [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary
        CGImageDestinationAddImage(destination, thumbnail, properties)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return destinationURL
    }
}
