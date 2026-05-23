//
//  URLHelpers.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-22.
//

import Foundation

extension URL {
    var isSupportedImage: Bool {
        let ext = pathExtension.lowercased()
        return ext == "png" || ext == "jpg" || ext == "jpeg"
    }

    func relativePath(from baseURL: URL) -> String {
        let base = baseURL.standardizedFileURL.path
        let path = standardizedFileURL.path
        guard path.hasPrefix(base) else { return path }
        return String(path.dropFirst(base.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
