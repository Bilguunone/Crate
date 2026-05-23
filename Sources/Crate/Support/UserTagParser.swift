//
//  UserTagParser.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import Foundation

enum UserTagParser {
    static func normalize(_ rawValue: String) -> (namespace: String, value: String)? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
        if parts.count == 2 {
            let namespace = Slug.make(String(parts[0]))
            let value = Slug.make(String(parts[1]))
            guard !namespace.isEmpty, !value.isEmpty else { return nil }
            return (namespace, value)
        }

        let value = Slug.make(trimmed)
        guard !value.isEmpty else { return nil }
        return ("user", value)
    }
}
