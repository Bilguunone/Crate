//
//  BrowseFilterMenu.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-24.
//

import SwiftUI

struct BrowseFilterMenu: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Menu {
            Menu("Kind") {
                Button("Any Kind") { model.setRefinedKind(nil) }
                Divider()
                ForEach(model.availableRefinementKinds, id: \.self) { kind in
                    Button(kind.capitalized) { model.setRefinedKind(kind) }
                }
            }

            Menu("Material") {
                Button("Any Material") { model.setRefinedMaterial(nil) }
                Divider()
                ForEach(model.availableRefinementMaterials, id: \.self) { material in
                    Button(material.capitalized) { model.setRefinedMaterial(material) }
                }
            }

            Menu("Use") {
                Button("Any Use") { model.setRefinedUse(nil) }
                Divider()
                ForEach(model.availableRefinementUses, id: \.self) { use in
                    Button(use.replacingOccurrences(of: "-", with: " ").capitalized) {
                        model.setRefinedUse(use)
                    }
                }
            }

            Menu("Alpha") {
                ForEach(AssetAlphaFilter.allCases) { filter in
                    Button(filter.title) { model.setRefinedAlpha(filter) }
                }
            }

            if model.hasRefinements {
                Divider()
                Button("Clear Filters") {
                    model.clearRefinements()
                }
            }
        } label: {
            Label(title, systemImage: "line.3.horizontal.decrease.circle")
        }
        .menuStyle(.button)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help("Filter visible assets")
    }

    private var title: String {
        let count = activeFilterCount
        guard count > 0 else { return "Filters" }
        return "\(count) Filter\(count == 1 ? "" : "s")"
    }

    private var activeFilterCount: Int {
        [
            model.refinedKind != nil,
            model.refinedMaterial != nil,
            model.refinedUse != nil,
            model.refinedAlpha != .any
        ].filter(\.self).count
    }
}

struct ActiveFilterChips: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 6) {
            if let kind = model.refinedKind {
                ActiveFilterChip(title: "Kind", value: kind.capitalized) {
                    model.setRefinedKind(nil)
                }
            }

            if let material = model.refinedMaterial {
                ActiveFilterChip(title: "Material", value: material.capitalized) {
                    model.setRefinedMaterial(nil)
                }
            }

            if let use = model.refinedUse {
                ActiveFilterChip(
                    title: "Use",
                    value: use.replacingOccurrences(of: "-", with: " ").capitalized
                ) {
                    model.setRefinedUse(nil)
                }
            }

            if model.refinedAlpha != .any {
                ActiveFilterChip(title: "Alpha", value: model.refinedAlpha.title) {
                    model.setRefinedAlpha(.any)
                }
            }
        }
    }
}

private struct ActiveFilterChip: View {
    let title: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title)
                    .foregroundStyle(.secondary)
                Text(value)
                    .fontWeight(.semibold)
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(CrateTheme.subtleFill)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .help("Remove \(title) filter")
    }
}
