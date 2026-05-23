//
//  CrateCLI+AssetCommands.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import Foundation

extension CrateCLI {
    func search(_ context: CLIContext, parser: inout CLIParser, json: Bool) throws {
        let options = SearchOptions(parser: &parser)
        let assets = try context.store.fetchAssets()
        let results = Array(filter(assets, options: options).prefix(options.limit))
        let favoriteIDs = try context.store.fetchFavoriteAssetIDs()

        if json {
            try printJSON(results.map { CLIAssetRecord(asset: $0, isFavorite: favoriteIDs.contains($0.id)) })
            return
        }
        for asset in results {
            print(line(for: asset))
        }
    }

    func show(_ context: CLIContext, parser: inout CLIParser, json: Bool) throws {
        guard let id = parser.next() else {
            throw CLIError.message("usage: cratectl show <asset-id>")
        }
        guard let asset = try context.store.fetchAssets().first(where: { $0.id == id }) else {
            throw CLIError.message("Asset not found: \(id)")
        }
        let isFavorite = try context.store.fetchFavoriteAssetIDs().contains(asset.id)

        if json {
            try printJSON(CLIAssetDetail(asset: asset, isFavorite: isFavorite))
            return
        }
        print("id: \(asset.id)")
        print("name: \(asset.displayName)")
        print("kind: \(asset.kind)")
        print("favorite: \(isFavorite ? "yes" : "no")")
        print("pack: \(asset.packID)")
        if let primary = asset.primaryVariant {
            print("primary: \(primary.fileURL.path)")
            print("size: \(primary.width)x\(primary.height)")
            print("alpha: \(primary.hasAlpha ? "yes" : "no")")
        }
        print("variants:")
        for variant in asset.variants {
            print("  \(variant.role.rawValue): \(variant.fileURL.path)")
        }
        print("tags:")
        for tag in asset.tags.sorted(by: tagSort) {
            print("  \(tag.namespace):\(tag.value) [\(tag.source)]")
        }
    }

    func similar(_ context: CLIContext, parser: inout CLIParser, json: Bool) throws {
        guard let id = parser.next() else {
            throw CLIError.message("usage: cratectl similar <asset-id> [--limit n]")
        }
        let limit = parser.intOption("--limit") ?? 12
        let assets = try context.store.fetchAssets()
        guard let asset = assets.first(where: { $0.id == id }) else {
            throw CLIError.message("Asset not found: \(id)")
        }
        let results = SimilarityService.similarAssets(to: asset, in: assets, limit: limit)
        let favoriteIDs = try context.store.fetchFavoriteAssetIDs()
        if json {
            try printJSON(results.map { CLIAssetRecord(asset: $0, isFavorite: favoriteIDs.contains($0.id)) })
            return
        }
        for result in results {
            print(line(for: result))
        }
    }

    func cart(_ context: CLIContext, parser: inout CLIParser, json: Bool) throws {
        guard let subcommand = parser.next() else {
            throw CLIError.message("usage: cratectl cart <list|add|add-search|remove|clear|export-folder|export-zip>")
        }

        switch subcommand {
        case "list":
            try cartList(context, json: json)
        case "add":
            try cartAdd(context, parser: &parser)
        case "add-search":
            try cartAddSearch(context, parser: &parser)
        case "remove":
            try cartRemove(context, parser: &parser)
        case "clear":
            try context.store.saveCart([])
            print("cart cleared")
        case "export-folder":
            let items = try context.store.fetchCart()
            let assetsByID = try assetsByID(context)
            let url = try ExportService.exportCartFolder(items: items, assetsByID: assetsByID, paths: context.paths)
            print(url.path)
        case "export-zip":
            let items = try context.store.fetchCart()
            let assetsByID = try assetsByID(context)
            let url = try ExportService.exportCartZip(items: items, assetsByID: assetsByID, paths: context.paths)
            print(url.path)
        default:
            throw CLIError.message("Unknown cart command: \(subcommand)")
        }
    }

    func cartList(_ context: CLIContext, json: Bool) throws {
        let items = try context.store.fetchCart()
        let assetsByID = try assetsByID(context)
        let records = items.compactMap { item -> CLICartItemRecord? in
            guard let asset = assetsByID[item.assetID] else { return nil }
            return CLICartItemRecord(item: item, asset: asset)
        }
        if json {
            try printJSON(records)
            return
        }
        if items.isEmpty {
            print("Cart empty.")
            return
        }
        for record in records {
            print("\(record.asset.id)\t\(record.asset.kind)\t\(record.asset.displayName)\t\(record.asset.primaryPath ?? "")")
        }
    }

    func cartAdd(_ context: CLIContext, parser: inout CLIParser) throws {
        let ids = parser.remainingNonOptions()
        guard !ids.isEmpty else {
            throw CLIError.message("usage: cratectl cart add <asset-id> [asset-id...]")
        }
        var items = try context.store.fetchCart()
        var existing = Set(items.map(\.assetID))
        let allIDs = Set(try context.store.fetchAssets().map(\.id))
        var added = 0

        for id in ids where !existing.contains(id) {
            guard allIDs.contains(id) else {
                throw CLIError.message("Asset not found: \(id)")
            }
            items.append(CartItem(id: UUID().uuidString, assetID: id, addedAt: Date()))
            existing.insert(id)
            try context.store.recordUsage(assetID: id, event: "carted")
            added += 1
        }

        try context.store.saveCart(items)
        print("added \(added), cart \(items.count)")
    }

    func cartAddSearch(_ context: CLIContext, parser: inout CLIParser) throws {
        let options = SearchOptions(parser: &parser, defaultLimit: 12)
        let matches = Array(filter(try context.store.fetchAssets(), options: options).prefix(options.limit))
        guard !matches.isEmpty else {
            print("no matches")
            return
        }

        var items = try context.store.fetchCart()
        var existing = Set(items.map(\.assetID))
        var added = 0
        for asset in matches where !existing.contains(asset.id) {
            items.append(CartItem(id: UUID().uuidString, assetID: asset.id, addedAt: Date()))
            existing.insert(asset.id)
            try context.store.recordUsage(assetID: asset.id, event: "carted")
            added += 1
        }
        try context.store.saveCart(items)
        print("added \(added), cart \(items.count)")
        for asset in matches {
            print(line(for: asset))
        }
    }

    func cartRemove(_ context: CLIContext, parser: inout CLIParser) throws {
        let ids = Set(parser.remainingNonOptions())
        guard !ids.isEmpty else {
            throw CLIError.message("usage: cratectl cart remove <asset-id> [asset-id...]")
        }
        var items = try context.store.fetchCart()
        items.removeAll { ids.contains($0.assetID) }
        try context.store.saveCart(items)
        print("cart \(items.count)")
    }

    func favorite(_ context: CLIContext, parser: inout CLIParser, json: Bool) throws {
        guard let subcommand = parser.next() else {
            throw CLIError.message("usage: cratectl favorite <list|add|remove|toggle>")
        }

        switch subcommand {
        case "list":
            try favoriteList(context, json: json)
        case "add":
            try favoriteSet(context, parser: &parser, isFavorite: true)
        case "remove":
            try favoriteSet(context, parser: &parser, isFavorite: false)
        case "toggle":
            try favoriteToggle(context, parser: &parser)
        default:
            throw CLIError.message("Unknown favorite command: \(subcommand)")
        }
    }

    func favoriteList(_ context: CLIContext, json: Bool) throws {
        let favoriteIDs = try context.store.fetchFavoriteAssetIDs()
        let assets = try context.store.fetchAssets()
            .filter { favoriteIDs.contains($0.id) }

        if json {
            try printJSON(assets.map { CLIAssetRecord(asset: $0, isFavorite: true) })
            return
        }

        if assets.isEmpty {
            print("No favorites.")
            return
        }

        for asset in assets {
            print(line(for: asset))
        }
    }

    func favoriteSet(_ context: CLIContext, parser: inout CLIParser, isFavorite: Bool) throws {
        let ids = parser.remainingNonOptions()
        guard !ids.isEmpty else {
            throw CLIError.message("usage: cratectl favorite \(isFavorite ? "add" : "remove") <asset-id> [asset-id...]")
        }

        try validateAssetIDs(ids, context: context)
        for id in ids {
            try context.store.setFavorite(assetID: id, isFavorite: isFavorite)
        }
        print("\(isFavorite ? "favorited" : "unfavorited") \(ids.count)")
    }

    func favoriteToggle(_ context: CLIContext, parser: inout CLIParser) throws {
        let ids = parser.remainingNonOptions()
        guard !ids.isEmpty else {
            throw CLIError.message("usage: cratectl favorite toggle <asset-id> [asset-id...]")
        }

        try validateAssetIDs(ids, context: context)
        var favoriteIDs = try context.store.fetchFavoriteAssetIDs()
        for id in ids {
            let nextValue = !favoriteIDs.contains(id)
            try context.store.setFavorite(assetID: id, isFavorite: nextValue)
            if nextValue {
                favoriteIDs.insert(id)
            } else {
                favoriteIDs.remove(id)
            }
        }
        print("favorites \(favoriteIDs.count)")
    }

    func tag(_ context: CLIContext, parser: inout CLIParser, json: Bool) throws {
        guard let subcommand = parser.next() else {
            throw CLIError.message("usage: cratectl tag <list|add|remove>")
        }

        switch subcommand {
        case "list":
            try tagList(context, parser: &parser, json: json)
        case "add":
            try tagAdd(context, parser: &parser)
        case "remove":
            try tagRemove(context, parser: &parser)
        default:
            throw CLIError.message("Unknown tag command: \(subcommand)")
        }
    }

    func tagList(_ context: CLIContext, parser: inout CLIParser, json: Bool) throws {
        guard let assetID = parser.next() else {
            throw CLIError.message("usage: cratectl tag list <asset-id>")
        }
        guard let asset = try context.store.fetchAssets().first(where: { $0.id == assetID }) else {
            throw CLIError.message("Asset not found: \(assetID)")
        }
        let tags = asset.tags
            .filter { $0.source == "user" && $0.protected }
            .sorted(by: tagSort)

        if json {
            try printJSON(tags.map(CLITagRecord.init(tag:)))
            return
        }

        if tags.isEmpty {
            print("No user tags.")
            return
        }
        for tag in tags {
            print("\(tag.namespace):\(tag.value)")
        }
    }

    func tagAdd(_ context: CLIContext, parser: inout CLIParser) throws {
        guard let assetID = parser.next() else {
            throw CLIError.message("usage: cratectl tag add <asset-id> <tag> [tag...]")
        }
        let tags = try parsedUserTags(parser.remainingNonOptions())
        try validateAssetIDs([assetID], context: context)
        for tag in tags {
            try context.store.saveUserTag(assetID: assetID, namespace: tag.namespace, value: tag.value)
        }
        print("added \(tags.count) tags")
    }

    func tagRemove(_ context: CLIContext, parser: inout CLIParser) throws {
        guard let assetID = parser.next() else {
            throw CLIError.message("usage: cratectl tag remove <asset-id> <tag> [tag...]")
        }
        let tags = try parsedUserTags(parser.remainingNonOptions())
        try validateAssetIDs([assetID], context: context)
        for tag in tags {
            try context.store.deleteUserTag(assetID: assetID, namespace: tag.namespace, value: tag.value)
        }
        print("removed \(tags.count) tags")
    }

    func collection(_ context: CLIContext, parser: inout CLIParser, json: Bool) throws {
        guard let subcommand = parser.next() else {
            throw CLIError.message("usage: cratectl collection <list|create>")
        }

        switch subcommand {
        case "list":
            let collections = try context.store.fetchCollections()
            if json {
                try printJSON(collections.map(CLICollectionRecord.init(collection:)))
                return
            }
            if collections.isEmpty {
                print("No collections.")
                return
            }
            for collection in collections {
                print("\(collection.id)\t\(collection.assetIDs.count)\t\(collection.name)")
            }
        case "create":
            try collectionCreate(context, parser: &parser)
        default:
            throw CLIError.message("Unknown collection command: \(subcommand)")
        }
    }

    func collectionCreate(_ context: CLIContext, parser: inout CLIParser) throws {
        guard let name = parser.next() else {
            throw CLIError.message("usage: cratectl collection create <name> [--from-cart | --asset id...]")
        }

        let fromCart = parser.hasFlag("--from-cart")
        let explicitAssets = parser.values(for: "--asset")
        let assetIDs: [String]
        if fromCart {
            assetIDs = try context.store.fetchCart().map(\.assetID)
        } else if !explicitAssets.isEmpty {
            assetIDs = explicitAssets
        } else {
            assetIDs = try context.store.fetchCart().map(\.assetID)
        }

        guard !assetIDs.isEmpty else {
            throw CLIError.message("No assets for collection. Add assets to cart or pass --asset <id>.")
        }

        let collection = AssetCollection(
            id: "collection-\(UUID().uuidString)",
            name: name,
            coverAssetID: assetIDs.first,
            createdAt: Date(),
            assetIDs: assetIDs
        )
        try context.store.saveCollection(collection)
        print("\(collection.id)\t\(collection.assetIDs.count)\t\(collection.name)")
    }

    func assetsByID(_ context: CLIContext) throws -> [String: DesignAsset] {
        Dictionary(uniqueKeysWithValues: try context.store.fetchAssets().map { ($0.id, $0) })
    }

    func validateAssetIDs(_ ids: [String], context: CLIContext) throws {
        let allIDs = Set(try context.store.fetchAssets().map(\.id))
        for id in ids where !allIDs.contains(id) {
            throw CLIError.message("Asset not found: \(id)")
        }
    }

    func parsedUserTags(_ rawTags: [String]) throws -> [(namespace: String, value: String)] {
        guard !rawTags.isEmpty else {
            throw CLIError.message("Pass at least one tag.")
        }

        return try rawTags.map { rawTag in
            guard let tag = UserTagParser.normalize(rawTag) else {
                throw CLIError.message("Invalid tag: \(rawTag)")
            }
            return tag
        }
    }

    func filter(_ assets: [DesignAsset], options: SearchOptions) -> [DesignAsset] {
        let query = options.query.lowercased()
        return assets.filter { asset in
            if !query.isEmpty {
                let searchable = [
                    asset.id,
                    asset.displayName,
                    asset.normalizedName,
                    asset.kind,
                    asset.packID
                ].joined(separator: " ").lowercased()
                let tagText = asset.tags.map { "\($0.namespace):\($0.value)" }.joined(separator: " ").lowercased()
                guard searchable.contains(query) || tagText.contains(query) else { return false }
            }

            if let kind = options.kind, asset.kind != kind {
                return false
            }

            for requiredTag in options.tags {
                guard asset.tags.contains(where: { "\($0.namespace):\($0.value)" == requiredTag || $0.value == requiredTag }) else {
                    return false
                }
            }

            if options.alphaOnly && !asset.hasAlpha {
                return false
            }

            return true
        }
    }

    func line(for asset: DesignAsset) -> String {
        let path = asset.primaryVariant?.fileURL.path ?? ""
        return "\(asset.id)\t\(asset.kind)\t\(asset.displayName)\t\(path)"
    }

    func tagSort(_ lhs: AssetTag, _ rhs: AssetTag) -> Bool {
        if lhs.namespace == rhs.namespace {
            return lhs.value < rhs.value
        }
        return lhs.namespace < rhs.namespace
    }
}
