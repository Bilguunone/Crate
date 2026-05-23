//
//  ImportReviewDraft.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import Foundation

struct ImportReviewDraft: Identifiable {
    let id = UUID()
    let sourceURL: URL
    var analysis: ImportFolderAnalysis
    var displayName: String
    var source: String
    var kind: String
    var material: String
    var subtype: String

    init(sourceURL: URL, analysis: ImportFolderAnalysis) {
        self.sourceURL = sourceURL
        self.analysis = analysis
        displayName = analysis.displayName
        source = analysis.source
        kind = analysis.inferredKind
        material = analysis.inferredMaterial
        subtype = analysis.inferredSubtype
    }

    var options: GenericImportOptions {
        GenericImportOptions(
            displayName: displayName.trimmedNonEmpty,
            source: source.trimmedNonEmpty,
            kind: kind.trimmedNonEmpty,
            material: material.trimmedNonEmpty,
            subtype: subtype.trimmedNonEmpty,
            packID: nil,
            shortCode: nil
        )
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
