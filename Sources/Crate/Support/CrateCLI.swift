//
//  CrateCLI.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-22.
//

import Foundation

struct CrateCLI {
    var arguments: [String]

    func run() -> Int {
        do {
            var parser = CLIParser(arguments: arguments)
            let explicitLibrary = arguments.contains("--library")
            let libraryRoot = parser.option("--library").map { URL(fileURLWithPath: $0, isDirectory: true) }
                ?? LibraryManager.savedRoot()
                ?? LibraryManager.suggestedRoot
            let json = parser.hasFlag("--json")

            guard let command = parser.next() else {
                printHelp()
                return 0
            }

            switch command {
            case "help", "--help", "-h":
                printHelp()
            case "analyze-folder":
                try analyzeFolder(parser: &parser, json: json)
            case "library":
                try library(libraryRoot: libraryRoot, explicitLibrary: explicitLibrary, parser: &parser, json: json)
            case "status":
                let context = try CLIContext(libraryRoot: libraryRoot)
                try status(context, json: json)
            case "packs":
                let context = try CLIContext(libraryRoot: libraryRoot)
                try packs(context, json: json)
            case "import-folder":
                let context = try CLIContext(libraryRoot: libraryRoot)
                try importFolder(context, parser: &parser)
            case "remove-pack":
                let context = try CLIContext(libraryRoot: libraryRoot)
                try removePack(context, parser: &parser, json: json)
            case "duplicates":
                let context = try CLIContext(libraryRoot: libraryRoot)
                try duplicates(context, parser: &parser, json: json)
            case "repair-thumbnails":
                let context = try CLIContext(libraryRoot: libraryRoot)
                try repairThumbnails(context, json: json)
            case "analyze-visual-tags":
                let context = try CLIContext(libraryRoot: libraryRoot)
                try analyzeVisualTags(context, json: json)
            case "search":
                let context = try CLIContext(libraryRoot: libraryRoot)
                try search(context, parser: &parser, json: json)
            case "show":
                let context = try CLIContext(libraryRoot: libraryRoot)
                try show(context, parser: &parser, json: json)
            case "similar":
                let context = try CLIContext(libraryRoot: libraryRoot)
                try similar(context, parser: &parser, json: json)
            case "cart":
                let context = try CLIContext(libraryRoot: libraryRoot)
                try cart(context, parser: &parser, json: json)
            case "favorite", "favorites":
                let context = try CLIContext(libraryRoot: libraryRoot)
                try favorite(context, parser: &parser, json: json)
            case "tag", "tags":
                let context = try CLIContext(libraryRoot: libraryRoot)
                try tag(context, parser: &parser, json: json)
            case "collection", "collections":
                let context = try CLIContext(libraryRoot: libraryRoot)
                try collection(context, parser: &parser, json: json)
            default:
                throw CLIError.message("Unknown command: \(command)")
            }
            return 0
        } catch {
            fputs("cratectl: \(error.localizedDescription)\n", stderr)
            return 1
        }
    }

}
