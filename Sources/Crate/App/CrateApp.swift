//
//  CrateApp.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-22.
//

import AppKit
import Darwin
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct CrateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    init() {
        if let exitCode = CommandLineImporter.runIfRequested() {
            exit(Int32(exitCode))
        }
    }

    var body: some Scene {
        WindowGroup("Crate") {
            ContentView()
                .environment(model)
                .tint(CrateTheme.accent)
                .accentColor(CrateTheme.accent)
                .frame(minWidth: 1180, minHeight: 760)
                .task {
                    await model.bootstrap()
                }
        }
        .windowStyle(.titleBar)
        .commands {
            CommandMenu("Crate") {
                Button("Import Folder...") {
                    model.chooseAndImportFolder()
                }
                .keyboardShortcut("o", modifiers: [.command])
                .disabled(!model.hasLibrary || model.isImporting)

                Button("Import Resource Boy Packs") {
                    Task { await model.importPresetPacks() }
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
                .disabled(!model.hasLibrary || model.isImporting)

                Button("Shuffle 12") {
                    model.shuffleCurrentResults()
                }
                .keyboardShortcut("r", modifiers: [.command, .option])
                .disabled(model.assets.isEmpty)

                Button("Reload Library") {
                    model.reloadLibrary()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(!model.hasLibrary)

                Button("Search") {
                    model.focusSearch()
                }
                .keyboardShortcut("f", modifiers: [.command])
                .disabled(!model.hasLibrary)

                Divider()

                Button("Reconnect Library...") {
                    model.chooseLibraryFolder()
                }
                .keyboardShortcut("l", modifiers: [.command, .option])

                Button("Move Library...") {
                    model.chooseLibraryMigrationDestination()
                }
                .keyboardShortcut("m", modifiers: [.command, .option])
                .disabled(!model.hasLibrary || model.isMigratingLibrary)

                Button("Validate Library") {
                    model.validateLibrary()
                }
                .keyboardShortcut("v", modifiers: [.command, .option])
                .disabled(!model.hasLibrary || model.isValidatingLibrary)

                Button("Scan Duplicates") {
                    model.scanDuplicates()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Button("Analyze Visual Tags") {
                    model.analyzeVisualTags()
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                .disabled(model.assets.isEmpty || model.isAnalyzingVisualTags)

                Button("Export Cart to Folder") {
                    Task { await model.exportCartToFolder() }
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(model.cartItems.isEmpty)
            }
        }
    }
}
