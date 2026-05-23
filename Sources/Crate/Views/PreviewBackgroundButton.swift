//
//  PreviewBackgroundButton.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import SwiftUI

struct PreviewBackgroundButton: View {
    let background: PreviewBackground
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? CrateTheme.accent.opacity(0.28) : Color.white.opacity(0.08))

                swatch
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .padding(4)
            }
            .frame(width: 30, height: 26)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? CrateTheme.accent : Color.white.opacity(0.22), lineWidth: isSelected ? 1.6 : 0.8)
            }
        }
        .buttonStyle(.plain)
        .help(background.title)
        .accessibilityLabel(background.title)
    }

    @ViewBuilder
    private var swatch: some View {
        switch background {
        case .checkerboard:
            CheckerboardView()
        case .white:
            Color.white
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(Color.black.opacity(0.16))
                }
        case .gray:
            Color(nsColor: .systemGray)
        case .black:
            Color.black
        }
    }
}
