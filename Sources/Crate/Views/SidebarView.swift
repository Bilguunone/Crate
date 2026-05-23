//
//  SidebarView.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-22.
//

import SwiftUI

struct SidebarView: View {
    @Environment(AppModel.self) private var model
    @State private var expandedSections = SidebarSection.defaultExpandedSections

    var body: some View {
        List {
            Section {
                SidebarRow(title: "All Assets", detail: "\(model.assets.count)", systemImage: "square.grid.3x3", filter: .all)
                SidebarRow(title: "Has Alpha", detail: "\(model.hasAlphaAssetCount)", systemImage: "checkerboard.rectangle", filter: .alpha)
                SidebarRow(title: "Shuffle 12", detail: "12 picks", systemImage: "shuffle", filter: .shuffle)
            }

            disclosureSection(.smartCollections) {
                ForEach(model.smartCollections) { collection in
                    SidebarRow(
                        title: collection.title,
                        detail: smartDetail(collection),
                        systemImage: collection.systemImage,
                        filter: .smart(collection.kind)
                    )
                }
            }

            disclosureSection(.packs) {
                if model.packs.isEmpty {
                    SidebarEmptyLabel("No packs yet")
                } else {
                    ForEach(model.packs) { pack in
                        PackSidebarRow(pack: pack)
                    }
                }
            }

            disclosureSection(.kind) {
                ForEach(model.kindFacets, id: \.self) { kind in
                    SidebarRow(title: kind.capitalized, detail: nil, systemImage: "tag", filter: .kind(kind))
                }
            }

            disclosureSection(.material) {
                ForEach(model.materialFacets, id: \.self) { material in
                    SidebarRow(title: material.capitalized, detail: nil, systemImage: "swatchpalette", filter: .material(material))
                }
            }

            disclosureSection(.use) {
                ForEach(model.useFacets, id: \.self) { use in
                    SidebarRow(title: use.replacingOccurrences(of: "-", with: " ").capitalized, detail: nil, systemImage: "wand.and.stars", filter: .use(use))
                }
            }

            if !model.userTagFacets.isEmpty {
                disclosureSection(.userTags) {
                    ForEach(model.userTagFacets) { tag in
                        SidebarRow(
                            title: tag.title,
                            detail: "\(tag.count)",
                            systemImage: "tag.fill",
                            filter: .userTag(tag.namespace, tag.value)
                        )
                    }
                }
            }

            if !model.colorFacets.isEmpty {
                disclosureSection(.color) {
                    ForEach(model.colorFacets, id: \.self) { color in
                        SidebarRow(
                            title: color.capitalized,
                            detail: nil,
                            systemImage: "circle.fill",
                            swatchColor: swatchColor(for: color),
                            filter: .tag("color", color)
                        )
                    }
                }
            }

            if model.hasVisualFacets {
                disclosureSection(.visual) {
                    ForEach(model.brightnessFacets, id: \.self) { value in
                        SidebarRow(title: "Brightness: \(value.capitalized)", detail: nil, systemImage: brightnessSymbol(for: value), filter: .tag("brightness", value))
                    }
                    ForEach(model.contrastFacets, id: \.self) { value in
                        SidebarRow(title: "Contrast: \(value.capitalized)", detail: nil, systemImage: contrastSymbol(for: value), filter: .tag("contrast", value))
                    }
                    ForEach(model.orientationFacets, id: \.self) { value in
                        SidebarRow(title: "Orientation: \(value.capitalized)", detail: nil, systemImage: orientationSymbol(for: value), filter: .tag("orientation", value))
                    }
                    ForEach(model.transparencyFacets, id: \.self) { value in
                        SidebarRow(title: "Transparency: \(value.capitalized)", detail: nil, systemImage: transparencySymbol(for: value), filter: .tag("transparency", value))
                    }
                    ForEach(model.edgeDensityFacets, id: \.self) { value in
                        SidebarRow(title: "Edges: \(value.capitalized)", detail: nil, systemImage: edgeDensitySymbol(for: value), filter: .tag("edge_density", value))
                    }
                }
            }

            disclosureSection(.collections) {
                if model.collections.isEmpty {
                    SidebarEmptyLabel("No collections yet")
                } else {
                    ForEach(model.collections) { collection in
                        SidebarRow(title: collection.name, detail: "\(collection.assetIDs.count)", systemImage: "rectangle.stack", filter: .collection(collection.id))
                    }
                }
            }

            disclosureSection(.importing) {
                Button {
                    model.chooseAndImportFolder()
                } label: {
                    Label("Import Folder", systemImage: "folder.badge.plus")
                }
                .disabled(model.isImporting)

                Button {
                    Task { await model.importPresetPacks() }
                } label: {
                    Label(model.isImporting ? "Importing..." : "Resource Boy Presets", systemImage: "square.and.arrow.down")
                }
                .disabled(model.isImporting)

                Button {
                    model.analyzeVisualTags()
                } label: {
                    Label(model.isAnalyzingVisualTags ? "Analyzing..." : "Analyze Visual Tags", systemImage: "camera.metering.matrix")
                }
                .disabled(model.assets.isEmpty || model.isAnalyzingVisualTags)
            }

            disclosureSection(.library) {
                Button {
                    model.chooseLibraryMigrationDestination()
                } label: {
                    Label(model.isMigratingLibrary ? "Moving Library..." : "Move Library", systemImage: "externaldrive.badge.plus")
                }
                .disabled(model.isMigratingLibrary)

                Button {
                    model.validateLibrary()
                } label: {
                    Label(model.isValidatingLibrary ? "Validating..." : "Validate Library", systemImage: "checkmark.seal")
                }
                .disabled(model.isValidatingLibrary)

                Button {
                    model.chooseLibraryFolder()
                } label: {
                    Label("Reconnect Library", systemImage: "link")
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            SidebarStatusView()
        }
    }

    @ViewBuilder
    private func disclosureSection<Content: View>(_ section: SidebarSection, @ViewBuilder content: @escaping () -> Content) -> some View {
        DisclosureGroup(isExpanded: binding(for: section)) {
            content()
        } label: {
            SidebarSectionHeader(title: section.title)
        }
    }

    private func binding(for section: SidebarSection) -> Binding<Bool> {
        Binding {
            expandedSections.contains(section)
        } set: { isExpanded in
            if isExpanded {
                expandedSections.insert(section)
            } else {
                expandedSections.remove(section)
            }
        }
    }

    private func smartDetail(_ collection: SmartCollectionDefinition) -> String {
        if let detail = collection.detail, !detail.isEmpty {
            return "\(collection.count) · \(detail)"
        }
        return "\(collection.count)"
    }

    private func swatchColor(for value: String) -> Color {
        switch value {
        case "black": .black
        case "white": .white
        case "gray": .gray
        case "red": .red
        case "orange": .orange
        case "yellow": .yellow
        case "green": .green
        case "cyan": .cyan
        case "blue": .blue
        case "purple": .purple
        case "pink": .pink
        default: .secondary
        }
    }

    private func brightnessSymbol(for value: String) -> String {
        switch value {
        case "dark": "moon.fill"
        case "bright": "sun.max.fill"
        default: "sun.min"
        }
    }

    private func contrastSymbol(for value: String) -> String {
        switch value {
        case "low": "circle"
        case "high": "circle.righthalf.filled"
        default: "circle.lefthalf.filled"
        }
    }

    private func orientationSymbol(for value: String) -> String {
        switch value {
        case "square": "square"
        case "portrait", "tall": "rectangle.portrait"
        case "panoramic": "rectangle.split.3x1"
        default: "rectangle"
        }
    }

    private func transparencySymbol(for value: String) -> String {
        switch value {
        case "none": "square.fill"
        case "full", "heavy": "checkerboard.rectangle"
        default: "square.dashed"
        }
    }

    private func edgeDensitySymbol(for value: String) -> String {
        switch value {
        case "soft": "line.diagonal"
        case "busy": "scribble.variable"
        default: "scribble"
        }
    }
}
