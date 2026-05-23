//
//  ContentView.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-22.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @SceneStorage("crate.inspectorPresented") private var isInspectorPresented = true
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        @Bindable var model = model

        Group {
            if model.hasLibrary {
                NavigationSplitView {
                    SidebarView()
                        .navigationSplitViewColumnWidth(min: 220, ideal: 248, max: 290)
                } detail: {
                    VStack(spacing: 0) {
                        AssetGridView()
                        CartTrayView()
                    }
                    .searchable(text: $model.searchText, placement: .toolbar, prompt: "Search assets, tags, filenames")
                    .crateSearchFocused($isSearchFocused)
                }
                .inspector(isPresented: $isInspectorPresented) {
                    InspectorView()
                        .inspectorColumnWidth(min: 320, ideal: 360, max: 420)
                }
                .toolbar {
                    ToolbarItemGroup {
                        Button {
                            model.chooseAndImportFolder()
                        } label: {
                            Label("Import Folder", systemImage: "folder.badge.plus")
                                .labelStyle(.iconOnly)
                        }
                        .help("Import Folder (Command-O)")
                        .disabled(model.isImporting)
                        .keyboardShortcut("o", modifiers: [.command])

                        Button {
                            Task { await model.importPresetPacks() }
                        } label: {
                            Label("Import Presets", systemImage: "square.and.arrow.down")
                                .labelStyle(.iconOnly)
                        }
                        .help("Import Presets (Shift-Command-I)")
                        .disabled(model.isImporting)
                        .keyboardShortcut("i", modifiers: [.command, .shift])

                        Button {
                            model.shuffleCurrentResults()
                        } label: {
                            Label("Shuffle 12", systemImage: "shuffle")
                                .labelStyle(.iconOnly)
                        }
                        .help("Shuffle 12 (Option-Command-R)")
                        .disabled(model.assets.isEmpty)
                        .keyboardShortcut("r", modifiers: [.command, .option])

                        Button {
                            model.reloadLibrary()
                        } label: {
                            Label("Reload", systemImage: "arrow.clockwise")
                                .labelStyle(.iconOnly)
                        }
                        .help("Reload Library (Command-R)")
                        .keyboardShortcut("r", modifiers: [.command])

                        Button {
                            Task { await model.exportCartToFolder() }
                        } label: {
                            Label("Export Cart", systemImage: "tray.and.arrow.up")
                                .labelStyle(.iconOnly)
                        }
                        .help("Export Cart (Shift-Command-E)")
                        .disabled(model.cartItems.isEmpty)
                        .keyboardShortcut("e", modifiers: [.command, .shift])
                    }
                }
                .onChange(of: model.searchFocusRequest) {
                    isSearchFocused = true
                }
                .sheet(isPresented: Binding(
                    get: { model.importReviewDraft != nil },
                    set: { isPresented in
                        if !isPresented {
                            model.cancelImportReview()
                        }
                    }
                )) {
                    ImportReviewView()
                }
                .confirmationDialog(
                    "Remove Pack?",
                    isPresented: Binding(
                        get: { model.pendingPackRemoval != nil },
                        set: { isPresented in
                            if !isPresented {
                                model.cancelRemovePack()
                            }
                        }
                    ),
                    presenting: model.pendingPackRemoval
                ) { pack in
                    Button("Remove from Crate") {
                        Task { await model.confirmRemovePack(deleteFromVault: false) }
                    }
                    Button("Delete from Vault Too", role: .destructive) {
                        Task { await model.confirmRemovePack(deleteFromVault: true) }
                    }
                    Button("Cancel", role: .cancel) {
                        model.cancelRemovePack()
                    }
                } message: { pack in
                    Text("\"\(pack.displayName)\" will disappear from Crate. Choose \"Remove from Crate\" to keep the image files in your library vault. Choose \"Delete from Vault Too\" to also delete Crate's copies from the DesignAssets folder. Your original import folder is not touched.")
                }
                .confirmationDialog(
                    "Remove Selected Assets?",
                    isPresented: Binding(
                        get: { !model.pendingAssetRemovalIDs.isEmpty },
                        set: { isPresented in
                            if !isPresented {
                                model.cancelRemoveAssets()
                            }
                        }
                    )
                ) {
                    Button("Remove from Crate") {
                        Task { await model.confirmRemoveAssets(deleteFromVault: false) }
                    }
                    Button("Delete from Vault Too", role: .destructive) {
                        Task { await model.confirmRemoveAssets(deleteFromVault: true) }
                    }
                    Button("Cancel", role: .cancel) {
                        model.cancelRemoveAssets()
                    }
                } message: {
                    Text("The selected assets will disappear from Crate. Choose \"Remove from Crate\" to keep the image files in your library vault. Choose \"Delete from Vault Too\" to also delete Crate's copies from the DesignAssets folder. Your original import folders are not touched.")
                }
                .confirmationDialog(
                    "Move Library",
                    isPresented: Binding(
                        get: { model.pendingLibraryMigration != nil },
                        set: { isPresented in
                            if !isPresented {
                                model.cancelLibraryMigration()
                            }
                        }
                    ),
                    presenting: model.pendingLibraryMigration
                ) { _ in
                    Button("Move Library") {
                        Task { await model.confirmLibraryMigration() }
                    }
                    Button("Cancel", role: .cancel) {
                        model.cancelLibraryMigration()
                    }
                } message: { plan in
                    Text("Crate will copy the library to \(plan.destinationRoot.path), update stored asset paths, validate the moved copy, save the new location, then remove the old copy at \(plan.sourceRoot.path).")
                }
                .navigationTitle("Crate")
            } else {
                LibrarySetupView()
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func crateSearchFocused(_ binding: FocusState<Bool>.Binding) -> some View {
        if #available(macOS 15.0, *) {
            searchFocused(binding)
        } else {
            self
        }
    }
}
