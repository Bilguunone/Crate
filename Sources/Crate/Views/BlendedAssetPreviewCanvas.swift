//
//  BlendedAssetPreviewCanvas.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import AppKit
import SwiftUI

struct BlendedAssetPreviewCanvas: View {
    let image: NSImage
    let background: PreviewBackground
    let blendMode: PreviewBlendMode
    let scale: CGFloat
    let offset: CGSize
    let rotation: Angle

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            drawBackground(in: &context, size: size)

            let container = CGRect(origin: .zero, size: size).insetBy(dx: 18, dy: 18)
            let fittedRect = fittedImageRect(for: image.size, in: container)
            guard !fittedRect.isEmpty else { return }

            context.translateBy(
                x: container.midX + offset.width,
                y: container.midY + offset.height
            )
            context.rotate(by: rotation)
            context.scaleBy(x: scale, y: scale)
            context.blendMode = blendMode.canvasBlendMode
            context.draw(
                Image(nsImage: image),
                in: CGRect(
                    x: -fittedRect.width / 2,
                    y: -fittedRect.height / 2,
                    width: fittedRect.width,
                    height: fittedRect.height
                )
            )
        }
    }

    private func drawBackground(in context: inout GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)

        switch background {
        case .checkerboard:
            context.fill(Path(rect), with: .color(Color(nsColor: .textBackgroundColor).opacity(0.72)))
            let tile: CGFloat = 10
            let rows = Int(ceil(size.height / tile))
            let columns = Int(ceil(size.width / tile))
            for row in 0..<rows {
                for column in 0..<columns where (row + column).isMultiple(of: 2) {
                    let tileRect = CGRect(
                        x: CGFloat(column) * tile,
                        y: CGFloat(row) * tile,
                        width: tile,
                        height: tile
                    )
                    context.fill(Path(tileRect), with: .color(Color.secondary.opacity(0.07)))
                }
            }
        case .white:
            context.fill(Path(rect), with: .color(.white))
        case .gray:
            context.fill(Path(rect), with: .color(Color(nsColor: .systemGray)))
        case .black:
            context.fill(Path(rect), with: .color(.black))
        }
    }

    private func fittedImageRect(for imageSize: CGSize, in container: CGRect) -> CGRect {
        guard imageSize.width > 0,
              imageSize.height > 0,
              container.width > 0,
              container.height > 0
        else { return .zero }

        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = container.width / container.height
        let fittedSize: CGSize

        if imageAspect > containerAspect {
            fittedSize = CGSize(width: container.width, height: container.width / imageAspect)
        } else {
            fittedSize = CGSize(width: container.height * imageAspect, height: container.height)
        }

        return CGRect(
            x: container.midX - fittedSize.width / 2,
            y: container.midY - fittedSize.height / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }
}
