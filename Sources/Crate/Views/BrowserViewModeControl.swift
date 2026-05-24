//
//  BrowserViewModeControl.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-24.
//

import SwiftUI

struct BrowserViewModeControl: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AssetBrowserViewMode.allCases) { mode in
                Button {
                    model.browserViewMode = mode
                } label: {
                    Image(systemName: mode.systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 26, height: 22)
                }
                .buttonStyle(.plain)
                .foregroundStyle(model.browserViewMode == mode ? CrateTheme.accent : .secondary)
                .background(model.browserViewMode == mode ? CrateTheme.accent.opacity(0.14) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .help("\(mode.title) View")
            }
        }
        .padding(3)
        .background(CrateTheme.subtleFill)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(CrateTheme.faintHairline)
        }
    }
}
