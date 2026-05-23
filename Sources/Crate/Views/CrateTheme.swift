//
//  CrateTheme.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-22.
//

import SwiftUI

enum CrateTheme {
    static let accent = Color(red: 0.184, green: 0.420, blue: 1.000)
    static let hairline = Color(nsColor: .separatorColor).opacity(0.42)
    static let faintHairline = Color(nsColor: .separatorColor).opacity(0.24)
    static let surface = Color(nsColor: .textBackgroundColor)
    static let raisedSurface = Color(nsColor: .controlBackgroundColor)
    static let selectedSurface = accent.opacity(0.12)
    static let subtleFill = Color.secondary.opacity(0.08)

    static let thumbnailRadius: CGFloat = 10
    static let panelRadius: CGFloat = 10
    static let chipRadius: CGFloat = 7
}

struct CratePreviewSurface<Content: View>: View {
    var cornerRadius: CGFloat = CrateTheme.thumbnailRadius
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            CheckerboardView()
            content
                .padding(10)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(CrateTheme.faintHairline)
        }
    }
}

struct CrateChip: View {
    let text: String
    var isSelected = false

    var body: some View {
        Text(text)
            .font(.caption2)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .foregroundStyle(isSelected ? CrateTheme.accent : .secondary)
            .background(isSelected ? CrateTheme.accent.opacity(0.12) : CrateTheme.subtleFill)
            .clipShape(RoundedRectangle(cornerRadius: CrateTheme.chipRadius, style: .continuous))
    }
}
