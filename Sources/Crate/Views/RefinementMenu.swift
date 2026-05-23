//
//  RefinementMenu.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import SwiftUI

struct RefinementMenu<Content: View>: View {
    let title: String
    let value: String
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        Menu {
            content
        } label: {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .symbolRenderingMode(.hierarchical)
                Text(title)
                    .foregroundStyle(.secondary)
                Text(value)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }
        }
        .menuStyle(.button)
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}
