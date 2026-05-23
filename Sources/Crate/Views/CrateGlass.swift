//
//  CrateGlass.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import SwiftUI

enum CrateGlassVariant {
    case regular
    case clear

    var fillOpacity: Double {
        switch self {
        case .regular: 0.07
        case .clear: 0.025
        }
    }

    var passiveFillOpacity: Double {
        switch self {
        case .regular: 0.045
        case .clear: 0.015
        }
    }

    var edgeOpacity: Double {
        switch self {
        case .regular: 0.42
        case .clear: 0.36
        }
    }

#if compiler(>=6.3)
    @available(macOS 26.0, *)
    func glass(interactive: Bool) -> Glass {
        let base: Glass = switch self {
        case .regular: .regular
        case .clear: .clear
        }

        return interactive ? base.interactive() : base
    }
#endif
}

struct CrateGlassPanelModifier: ViewModifier {
    let cornerRadius: CGFloat
    var interactive = false
    var variant: CrateGlassVariant = .regular

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

#if compiler(>=6.3)
        if #available(macOS 26.0, *) {
            glassPanel(content: content, shape: shape)
        } else {
            fallbackPanel(content: content, shape: shape)
        }
#else
        fallbackPanel(content: content, shape: shape)
#endif
    }

#if compiler(>=6.3)
    @available(macOS 26.0, *)
    private func glassPanel(content: Content, shape: RoundedRectangle) -> some View {
        let glass = variant.glass(interactive: interactive)
            .tint(Color.white.opacity(interactive ? 0.14 : 0.08))

        return content
            .background(Color.white.opacity(interactive ? variant.fillOpacity : variant.passiveFillOpacity), in: shape)
            .glassEffect(glass, in: .rect(cornerRadius: cornerRadius))
            .overlay {
                shape
                    .strokeBorder(Color.white.opacity(interactive ? variant.edgeOpacity : 0.30), lineWidth: 0.8)
                    .blendMode(.plusLighter)
            }
            .overlay {
                shape
                    .strokeBorder(Color.black.opacity(0.18), lineWidth: 0.7)
                    .blendMode(.multiply)
            }
            .shadow(color: Color.black.opacity(interactive ? 0.22 : 0.14), radius: interactive ? 16 : 10, y: 5)
    }
#endif

    private func fallbackPanel(content: Content, shape: RoundedRectangle) -> some View {
        content
            .background(
                .ultraThinMaterial,
                in: shape
            )
            .overlay {
                shape
                    .stroke(CrateTheme.faintHairline)
            }
    }
}

extension View {
    func crateGlassPanel(
        cornerRadius: CGFloat,
        interactive: Bool = false,
        variant: CrateGlassVariant = .regular
    ) -> some View {
        modifier(CrateGlassPanelModifier(cornerRadius: cornerRadius, interactive: interactive, variant: variant))
    }

    @ViewBuilder
    func crateGlassButtonStyle(variant: CrateGlassVariant = .regular) -> some View {
#if compiler(>=6.3)
        if #available(macOS 26.0, *) {
            switch variant {
            case .regular:
                buttonStyle(.glass)
            case .clear:
                buttonStyle(.glass(.clear.interactive()))
            }
        } else {
            buttonStyle(.borderless)
        }
#else
        buttonStyle(.borderless)
#endif
    }
}
