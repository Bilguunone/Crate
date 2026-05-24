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
    private let compactInspectorBreakpoint: CGFloat = 1_160

    var body: some View {
        @Bindable var model = model

        Group {
            if model.hasLibrary {
                GeometryReader { proxy in
                    let usesCompactInspector = proxy.size.width < compactInspectorBreakpoint
                    let suppressesInspector = modeOwnsPreview(model.browserViewMode)

                    NavigationSplitView {
                        SidebarView()
                            .navigationSplitViewColumnWidth(min: 184, ideal: 224, max: 268)
                    } detail: {
                        AssetGridView()
                            .crateCartAccessory()
                        .searchable(text: $model.searchText, placement: .toolbar, prompt: "Search assets, tags, filenames")
                        .crateSearchFocused($isSearchFocused)
                    }
                    .inspector(isPresented: inspectorPresentationBinding(isCompact: usesCompactInspector, isSuppressed: suppressesInspector)) {
                        InspectorView()
                            .inspectorColumnWidth(min: 300, ideal: 340, max: 400)
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
                                isInspectorPresented.toggle()
                            } label: {
                                Label("Inspector", systemImage: "sidebar.right")
                                    .labelStyle(.iconOnly)
                            }
                            .help(inspectorToggleHelp(isCompact: usesCompactInspector, isSuppressed: suppressesInspector))
                            .disabled(usesCompactInspector || suppressesInspector)
                        }
                    }
                    .onChange(of: model.browserViewMode) {
                        syncInspectorPresentation(for: model.browserViewMode)
                    }
                    .onChange(of: model.searchFocusRequest) {
                        isSearchFocused = true
                    }
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

    private func inspectorPresentationBinding(isCompact: Bool, isSuppressed: Bool) -> Binding<Bool> {
        Binding {
            isInspectorPresented && !isCompact && !isSuppressed
        } set: { isPresented in
            isInspectorPresented = isPresented
        }
    }

    private func inspectorToggleHelp(isCompact: Bool, isSuppressed: Bool) -> String {
        if isSuppressed {
            return "This view already includes the preview and asset actions"
        }
        if isCompact {
            return "Widen the window to show the inspector"
        }
        return "Toggle Inspector"
    }

    private func syncInspectorPresentation(for mode: AssetBrowserViewMode) {
        withAnimation(.easeOut(duration: 0.18)) {
            isInspectorPresented = !modeOwnsPreview(mode)
        }
    }

    private func modeOwnsPreview(_ mode: AssetBrowserViewMode) -> Bool {
        mode == .filmstrip || mode == .compare
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

    @ViewBuilder
    func crateCartAccessory() -> some View {
        cartAccessoryOverlay()
    }

    func cartAccessoryOverlay() -> some View {
        overlay(alignment: .bottom) {
            CartAccessoryHost()
        }
    }
}

private struct CartAccessoryHost: View {
    @Environment(AppModel.self) private var model
    @Namespace private var cartGlassNamespace

    var body: some View {
        ZStack(alignment: .bottom) {
            if !model.cartItems.isEmpty {
                CartAccessoryBackdrop()
                    .transition(.opacity)
            }

            transitioningCartTray
        }
        .frame(maxWidth: .infinity)
        .animation(.snappy(duration: 0.32, extraBounce: 0.08), value: model.cartItems.isEmpty)
    }

    @ViewBuilder
    private var transitioningCartTray: some View {
#if compiler(>=6.3)
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 18) {
                if !model.cartItems.isEmpty {
                    cartTray
                        .glassEffectID("crate-cart-bar", in: cartGlassNamespace)
                        .glassEffectTransition(.materialize)
                        .transition(cartFallbackTransition)
                }
            }
        } else {
            if !model.cartItems.isEmpty {
                cartTray
                    .transition(cartFallbackTransition)
            }
        }
#else
        if !model.cartItems.isEmpty {
            cartTray
                .transition(cartFallbackTransition)
        }
#endif
    }

    private var cartTray: some View {
        CartTrayView()
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
    }

    private var cartFallbackTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .bottom)),
            removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .bottom))
        )
    }
}

private struct CartAccessoryBackdrop: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .frame(height: 158)
                .opacity(0.72)
                .mask(backdropMask(start: 0.04, middle: 0.48))

            Rectangle()
                .fill(.regularMaterial)
                .frame(height: 106)
                .opacity(0.62)
                .mask(backdropMask(start: 0.0, middle: 0.36))

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: Color(nsColor: .windowBackgroundColor).opacity(0.18), location: 0.46),
                    .init(color: Color(nsColor: .windowBackgroundColor).opacity(0.50), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 148)
        }
        .frame(height: 164)
        .offset(y: 38)
        .allowsHitTesting(false)
    }

    private func backdropMask(start: Double, middle: Double) -> some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: start),
                .init(color: .black.opacity(0.20), location: middle),
                .init(color: .black, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
