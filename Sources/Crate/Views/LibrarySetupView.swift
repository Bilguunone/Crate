//
//  LibrarySetupView.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-22.
//

import SwiftUI

struct LibrarySetupView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            header

            VStack(alignment: .leading, spacing: 10) {
                if model.missingLibraryRoot != nil {
                    Button {
                        model.chooseLibraryFolder()
                    } label: {
                        Label("Reconnect Library", systemImage: "link")
                            .frame(width: 290, alignment: .leading)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)

                    Button {
                        model.forgetMissingLibrary()
                    } label: {
                        Label("Forget Missing Library", systemImage: "xmark.circle")
                            .frame(width: 290, alignment: .leading)
                    }
                    .controlSize(.large)
                } else {
                    Button {
                        model.useSuggestedLibrary()
                    } label: {
                        Label("Create ~/Documents/DesignAssets", systemImage: "folder.badge.plus")
                            .frame(width: 290, alignment: .leading)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                }

                Button {
                    model.chooseLibraryFolder()
                } label: {
                    Label(model.missingLibraryRoot == nil ? "Choose Another Folder" : "Choose Different Folder", systemImage: "folder")
                        .frame(width: 290, alignment: .leading)
                }
                .controlSize(.large)
            }

            Text(model.statusMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(64)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: model.missingLibraryRoot == nil ? "shippingbox" : "externaldrive.badge.xmark")
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(model.missingLibraryRoot == nil ? Color.secondary : Color.orange)

            Text(model.missingLibraryRoot == nil ? "Crate" : "Library Drive Missing")
                .font(.largeTitle)
                .fontWeight(.semibold)
            Text(headerDetail)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 680, alignment: .leading)
        }
    }

    private var headerDetail: String {
        if let missingLibraryRoot = model.missingLibraryRoot {
            return "Crate saved a library at \(missingLibraryRoot.path), but that location is not available. Plug the drive back in or reconnect the moved library folder."
        }
        return "A local browser for texture packs, overlays, stickers, and the design scraps Finder keeps making spiritually boring."
    }
}
