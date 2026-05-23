//
//  SidebarComponents.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import SwiftUI

struct SidebarSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

struct SidebarEmptyLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.vertical, 3)
    }
}

struct PackSidebarRow: View {
    @Environment(AppModel.self) private var model

    let pack: AssetPack

    var body: some View {
        SidebarRow(title: pack.displayName, detail: "\(pack.assetCount)", systemImage: "shippingbox", filter: .pack(pack.id))
            .contextMenu {
                Button("Remove Pack", role: .destructive) {
                    model.requestRemovePack(pack)
                }
            }
    }
}

struct SidebarStatusView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if model.isMigratingLibrary {
                Label("Moving library", systemImage: "externaldrive.badge.plus")
                    .foregroundStyle(.secondary)
                Text(model.statusMessage)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            } else if model.isValidatingLibrary {
                Label("Validating library", systemImage: "checkmark.seal")
                    .foregroundStyle(.secondary)
            } else if model.isImporting {
                Label("Importing packs", systemImage: "arrow.down.circle")
                    .foregroundStyle(.secondary)
            } else if model.statusMessage.lowercased().contains("error")
                || model.statusMessage.lowercased().contains("does not exist") {
                Label("Import needs attention", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text(model.statusMessage)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else if let root = model.libraryRoot {
                Label(root.lastPathComponent, systemImage: "externaldrive")
                    .foregroundStyle(.secondary)
                Text(root.path)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let report = model.libraryValidationReport {
                    Text(report.summary)
                        .foregroundStyle(report.isUsable ? Color.secondary.opacity(0.7) : Color.orange)
                        .lineLimit(1)
                }
            } else {
                Text(model.statusMessage)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }
}

struct SidebarRow: View {
    @Environment(AppModel.self) private var model

    let title: String
    let detail: String?
    let systemImage: String
    var swatchColor: Color?
    let filter: SidebarFilter

    var body: some View {
        let isSelected = model.selectedFilter == filter

        Button {
            model.applyFilter(filter)
        } label: {
            HStack(spacing: 10) {
                icon(isSelected: isSelected)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .lineLimit(1)
                    if let detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background(isSelected ? CrateTheme.selectedSurface : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .primary : .secondary)
    }

    @ViewBuilder
    private func icon(isSelected: Bool) -> some View {
        if let swatchColor {
            Circle()
                .fill(swatchColor)
                .overlay {
                    Circle()
                        .stroke(CrateTheme.faintHairline, lineWidth: 1)
                }
                .frame(width: 10, height: 10)
                .frame(width: 16)
        } else {
            Image(systemName: systemImage)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isSelected ? CrateTheme.accent : .secondary)
                .frame(width: 16)
        }
    }
}
