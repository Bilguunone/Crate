//
//  InteractiveAssetPreview.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import AppKit
import SwiftUI

struct InteractiveAssetPreview: View {
    let url: URL?

    @State private var image: NSImage?
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var rotation: Angle = .zero

    @AppStorage("crate.preview.background") private var backgroundRawValue = PreviewBackground.checkerboard.rawValue
    @AppStorage("crate.preview.blendMode") private var blendModeRawValue = PreviewBlendMode.normal.rawValue

    private var selectedBackground: PreviewBackground {
        get { PreviewBackground(rawValue: backgroundRawValue) ?? .checkerboard }
        nonmutating set { backgroundRawValue = newValue.rawValue }
    }

    private var selectedBlendMode: PreviewBlendMode {
        get { PreviewBlendMode(rawValue: blendModeRawValue) ?? .normal }
        nonmutating set { blendModeRawValue = newValue.rawValue }
    }

    private var blendModeBinding: Binding<PreviewBlendMode> {
        Binding(
            get: { selectedBlendMode },
            set: { selectedBlendMode = $0 }
        )
    }

    var body: some View {
        stage
            .frame(height: 316)
            .task(id: url) {
                resetTransform()
                await loadImage(for: url)
            }
    }

    private var stage: some View {
        ZStack {
            if let image {
                BlendedAssetPreviewCanvas(
                    image: image,
                    background: selectedBackground,
                    blendMode: selectedBlendMode,
                    scale: scale,
                    offset: offset,
                    rotation: rotation
                )
            } else {
                backgroundView
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(CrateTheme.faintHairline)
        }
        .overlay {
            PreviewGestureLayer(
                onPan: { delta in
                    offset = offset + delta
                },
                onMagnify: { delta in
                    scale = clamp(scale * max(0.05, 1 + delta), min: 0.25, max: 10)
                },
                onRotate: { degrees in
                    rotation = rotation + .degrees(Double(degrees))
                },
                onReset: {
                    resetTransform(animated: true)
                }
            )
        }
        .overlay(alignment: .topLeading) {
            transformBadge
                .padding(10)
        }
        .overlay(alignment: .bottom) {
            previewControls
                .padding(10)
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch selectedBackground {
        case .checkerboard:
            CheckerboardView()
        case .white:
            Color.white
        case .gray:
            Color(nsColor: .systemGray)
        case .black:
            Color.black
        }
    }

    private var transformBadge: some View {
        Text("\(Int(scale * 100))% · \(Int(rotation.degrees.rounded()))°")
            .font(.caption2)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .crateGlassPanel(cornerRadius: 12)
    }

    @ViewBuilder
    private var previewControls: some View {
#if compiler(>=6.3)
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 7) {
                HStack(spacing: 7) {
                    controlsContent
                        .crateGlassPanel(cornerRadius: 17, interactive: true, variant: .clear)

                    resetButton
                }
            }
        } else {
            fallbackPreviewControls
        }
#else
        fallbackPreviewControls
#endif
    }

    private var fallbackPreviewControls: some View {
        HStack(spacing: 7) {
            controlsContent

            Divider()
                .frame(height: 18)
                .opacity(0.55)

            resetButton
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .crateGlassPanel(cornerRadius: 17, interactive: true)
    }

    private var controlsContent: some View {
        HStack(spacing: 7) {
            backgroundControls

            Divider()
                .frame(height: 18)
                .opacity(0.55)

            blendModePicker
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
    }

    private var backgroundControls: some View {
        HStack(spacing: 5) {
            ForEach(PreviewBackground.allCases) { background in
                PreviewBackgroundButton(
                    background: background,
                    isSelected: selectedBackground == background
                ) {
                    selectedBackground = background
                }
            }
        }
    }

    private var blendModePicker: some View {
        Picker("Blend", selection: blendModeBinding) {
            ForEach(PreviewBlendMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .controlSize(.small)
        .frame(width: 116)
        .help("Try blend modes against the selected preview background")
    }

    private var resetButton: some View {
        Button {
            resetTransform(animated: true)
        } label: {
            Label("Reset", systemImage: "arrow.counterclockwise")
                .labelStyle(.iconOnly)
        }
        .controlSize(.small)
        .crateGlassButtonStyle(variant: .clear)
        .help("Reset preview transform")
    }

    private func loadImage(for url: URL?) async {
        guard let url else {
            image = nil
            return
        }

        image = nil
        guard let data = await PreviewImageLoader.imageData(for: url),
              !Task.isCancelled
        else { return }

        image = NSImage(data: data)
    }

    private func resetTransform(animated: Bool = false) {
        let changes = {
            scale = 1
            offset = .zero
            rotation = .zero
        }

        if animated {
            withAnimation(.easeOut(duration: 0.18), changes)
        } else {
            changes()
        }
    }

    private func clamp(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minimum), maximum)
    }
}
