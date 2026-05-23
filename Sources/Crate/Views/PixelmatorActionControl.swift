//
//  PixelmatorActionControl.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-24.
//

import SwiftUI

enum PixelmatorActionScope {
    case asset(DesignAsset)
    case selection
    case cart
}

struct PixelmatorActionControl: View {
    @Environment(AppModel.self) private var model

    let scope: PixelmatorActionScope
    var compact = false

    var body: some View {
        HStack(spacing: 1) {
            Button(action: primaryAction) {
                Label(primaryTitle, systemImage: "photo.badge.plus")
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isDisabled || primaryIsMissingSavedProject)
            .help(primaryHelp)

            Menu {
                if canUseOpenProject {
                    Button(action: sendToOpenProject) {
                        Label("Add to \(projectTitle)", systemImage: "photo.badge.plus")
                    }
                } else if model.hasOpenPixelmatorProject {
                    Label("Save the Pixelmator project first", systemImage: "externaldrive.badge.exclamationmark")
                }

                Button(action: chooseDocument) {
                    Label("Choose Pixelmator Document...", systemImage: "doc.badge.plus")
                }

                Divider()

                Button(action: model.choosePixelmatorBridgeTool) {
                    Label("Choose pxdctl...", systemImage: "terminal")
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: compact ? 24 : 28)
            }
            .menuStyle(.button)
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isDisabled)
            .help("Pixelmator options")
        }
        .fixedSize(horizontal: false, vertical: true)
        .task {
            await model.refreshPixelmatorProjectStatus()
        }
    }

    private var isDisabled: Bool {
        model.isSendingToPixelmator || assetCount == 0
    }

    private var assetCount: Int {
        switch scope {
        case .asset:
            1
        case .selection:
            model.selectedAssetCount
        case .cart:
            model.cartItems.count
        }
    }

    private var canUseOpenProject: Bool {
        model.pixelmatorFrontDocumentURL != nil
    }

    private var primaryIsMissingSavedProject: Bool {
        model.hasOpenPixelmatorProject && model.pixelmatorFrontDocumentURL == nil
    }

    private var primaryTitle: String {
        if canUseOpenProject {
            return "Add to \(quoted(projectTitle))"
        }
        if primaryIsMissingSavedProject {
            return "Save Project First"
        }
        return "Choose Pixelmator Project"
    }

    private var projectTitle: String {
        truncated(model.pixelmatorOpenProjectTitle, maxLength: compact ? 22 : 30)
    }

    private var primaryHelp: String {
        if canUseOpenProject {
            return "Add \(assetCount == 1 ? "asset" : "\(assetCount) assets") to the front Pixelmator project"
        }
        if primaryIsMissingSavedProject {
            return "Save the front Pixelmator project as a .pxd before Crate can add assets to it"
        }
        return "Choose a Pixelmator .pxd document and add \(assetCount == 1 ? "this asset" : "these assets")"
    }

    private func primaryAction() {
        canUseOpenProject ? sendToOpenProject() : chooseDocument()
    }

    private func sendToOpenProject() {
        switch scope {
        case .asset(let asset):
            model.sendAssetToOpenPixelmatorProject(asset)
        case .selection:
            model.sendSelectedToOpenPixelmatorProject()
        case .cart:
            model.sendCartToOpenPixelmatorProject()
        }
    }

    private func chooseDocument() {
        switch scope {
        case .asset(let asset):
            model.sendAssetToChosenPixelmatorDocument(asset)
        case .selection:
            model.sendSelectedToChosenPixelmatorDocument()
        case .cart:
            model.sendCartToChosenPixelmatorDocument()
        }
    }

    private func quoted(_ value: String) -> String {
        "\"\(value)\""
    }

    private func truncated(_ value: String, maxLength: Int) -> String {
        guard value.count > maxLength else { return value }
        let prefixCount = max(4, maxLength - 5)
        return "\(value.prefix(prefixCount))..."
    }
}
