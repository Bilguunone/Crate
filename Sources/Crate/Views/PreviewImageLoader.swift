//
//  PreviewImageLoader.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import Foundation

enum PreviewImageLoader {
    static func imageData(for url: URL) async -> Data? {
        await ImageDownsampler.previewData(for: url)
    }
}
