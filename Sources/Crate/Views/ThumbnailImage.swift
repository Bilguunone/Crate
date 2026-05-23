//
//  ThumbnailImage.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-22.
//

import AppKit
import SwiftUI

struct ThumbnailImage: View {
    let url: URL?
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: url) {
            guard let url else {
                image = nil
                return
            }
            image = nil
            guard let data = await ImageDownsampler.thumbnailData(for: url),
                  !Task.isCancelled
            else { return }
            image = NSImage(data: data)
        }
    }
}

struct CheckerboardView: View {
    var body: some View {
        Canvas { context, size in
            let tile: CGFloat = 10
            let rows = Int(ceil(size.height / tile))
            let columns = Int(ceil(size.width / tile))
            for row in 0..<rows {
                for column in 0..<columns where (row + column).isMultiple(of: 2) {
                    let rect = CGRect(x: CGFloat(column) * tile, y: CGFloat(row) * tile, width: tile, height: tile)
                    context.fill(Path(rect), with: .color(Color.secondary.opacity(0.07)))
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(0.72))
    }
}
