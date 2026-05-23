//
//  AssetGridEmptyState.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import SwiftUI

struct AssetEmptyState: View {
    @Environment(AppModel.self) private var model

    let isLibraryEmpty: Bool

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: isLibraryEmpty ? "shippingbox" : "line.3.horizontal.decrease.circle")
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(.tertiary)

            VStack(spacing: 6) {
                Text(isLibraryEmpty ? "Import your first pack" : "No matching assets")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            HStack(spacing: 8) {
                if isLibraryEmpty {
                    Button {
                        model.chooseAndImportFolder()
                    } label: {
                        Label("Import Folder", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isImporting)

                    Button {
                        Task { await model.importPresetPacks() }
                    } label: {
                        Label("Import Presets", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.isImporting)

                    Button {
                        model.chooseLibraryFolder()
                    } label: {
                        Label("Choose Library", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        model.searchText = ""
                        model.clearRefinements()
                        model.applyFilter(.all)
                    } label: {
                        Label("Clear Filters", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var message: String {
        if isLibraryEmpty {
            return "Library selected. Now import a folder of PNG/JPG assets. The library is storage, not the source pack. Annoying distinction, useful system."
        }
        return "Clear search or switch filters to get back to the library."
    }
}
