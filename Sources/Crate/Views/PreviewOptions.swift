//
//  PreviewOptions.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import SwiftUI

enum PreviewBackground: String, CaseIterable, Identifiable {
    case checkerboard
    case white
    case gray
    case black

    var id: String { rawValue }

    var title: String {
        switch self {
        case .checkerboard: "Grid"
        case .white: "White"
        case .gray: "Gray"
        case .black: "Black"
        }
    }
}

enum PreviewBlendMode: String, CaseIterable, Identifiable {
    case normal
    case multiply
    case screen
    case overlay
    case softLight
    case hardLight
    case darken
    case lighten
    case difference

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: "Normal"
        case .multiply: "Multiply"
        case .screen: "Screen"
        case .overlay: "Overlay"
        case .softLight: "Soft Light"
        case .hardLight: "Hard Light"
        case .darken: "Darken"
        case .lighten: "Lighten"
        case .difference: "Difference"
        }
    }

    var canvasBlendMode: GraphicsContext.BlendMode {
        switch self {
        case .normal: .normal
        case .multiply: .multiply
        case .screen: .screen
        case .overlay: .overlay
        case .softLight: .softLight
        case .hardLight: .hardLight
        case .darken: .darken
        case .lighten: .lighten
        case .difference: .difference
        }
    }
}

extension CGSize {
    static func + (lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }
}
