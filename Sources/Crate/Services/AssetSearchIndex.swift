//
//  AssetSearchIndex.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import Foundation

struct AssetSearchDocument: Sendable, Hashable {
    let assetID: String
    let displayName: String
    let normalizedName: String
    let kind: String
    let packName: String
    let nameTokens: Set<String>
    let tagTokens: Set<String>
    let allTokens: Set<String>
    let haystack: String

    init(asset: DesignAsset, packName: String) {
        assetID = asset.id
        displayName = AssetSearchDocument.normalize(asset.displayName)
        normalizedName = AssetSearchDocument.normalize(asset.normalizedName)
        kind = AssetSearchDocument.normalize(asset.kind)
        self.packName = AssetSearchDocument.normalize(packName)

        let tagText = asset.tags
            .flatMap { [$0.namespace, $0.value] }
            .joined(separator: " ")
        nameTokens = Set(AssetSearchDocument.tokenize([asset.displayName, asset.normalizedName].joined(separator: " ")))
        tagTokens = Set(AssetSearchDocument.tokenize(tagText))

        let terms = AssetSearchDocument.tokenize(
            [
                asset.displayName,
                asset.normalizedName,
                asset.kind,
                packName,
                tagText
            ].joined(separator: " ")
        )
        allTokens = Set(terms)
        haystack = terms.joined(separator: " ")
    }

    func score(for query: AssetSearchQuery) -> Double {
        guard !query.terms.isEmpty,
              query.terms.allSatisfy(matches(term:))
        else { return 0 }

        var score = 1.0
        if displayName == query.normalized || normalizedName == query.normalized {
            score += 500
        }
        if displayName.hasPrefix(query.normalized) || normalizedName.hasPrefix(query.normalized) {
            score += 260
        }
        if displayName.contains(query.normalized) {
            score += 180
        }
        if normalizedName.contains(query.normalized) {
            score += 140
        }
        if kind.contains(query.normalized) {
            score += 70
        }
        if packName.contains(query.normalized) {
            score += 40
        }

        for term in query.terms {
            if nameTokens.contains(term) {
                score += 45
            } else if nameTokens.contains(where: { $0.hasPrefix(term) }) {
                score += 28
            }

            if tagTokens.contains(term) {
                score += 26
            } else if tagTokens.contains(where: { $0.hasPrefix(term) }) {
                score += 14
            }
        }

        return score
    }

    private func matches(term: String) -> Bool {
        allTokens.contains(term)
            || allTokens.contains(where: { $0.hasPrefix(term) })
            || haystack.contains(term)
    }

    static func normalize(_ string: String) -> String {
        string
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func tokenize(_ string: String) -> [String] {
        normalize(string)
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }
    }
}

struct AssetSearchQuery: Sendable, Hashable {
    let normalized: String
    let terms: [String]

    init(_ rawValue: String) {
        normalized = AssetSearchDocument.normalize(rawValue)
        terms = AssetSearchDocument.tokenize(rawValue)
    }
}
