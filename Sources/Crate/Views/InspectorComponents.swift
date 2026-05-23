//
//  InspectorComponents.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import SwiftUI

struct InspectorSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InspectorMetadataRow: View {
    let title: String
    let value: String

    init(_ title: String, _ value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.callout)
    }
}

struct VariantRow: View {
    let variant: AssetVariant
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? CrateTheme.accent : .secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(variant.role.rawValue.capitalized)
                    .font(.callout)
                Text("\(variant.width) x \(variant.height)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(variant.fileExtension.uppercased())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(isSelected ? CrateTheme.selectedSurface : CrateTheme.subtleFill)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct SimilarAssetRow: View {
    let asset: DesignAsset

    var body: some View {
        HStack(spacing: 9) {
            CratePreviewSurface(cornerRadius: 6) {
                ThumbnailImage(url: asset.thumbnailURL ?? asset.primaryVariant?.fileURL)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(asset.displayName)
                    .lineLimit(1)
                Text(asset.kind.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(6)
        .background(CrateTheme.subtleFill)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct InspectorDeferredSectionPlaceholder: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Preparing details")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
