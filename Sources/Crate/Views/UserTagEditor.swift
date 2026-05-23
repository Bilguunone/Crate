//
//  UserTagEditor.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import SwiftUI

struct UserTagEditor: View {
    @Environment(AppModel.self) private var model

    let asset: DesignAsset
    @Binding var draft: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                TextField("namespace:value or tag", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addTag)

                Button {
                    addTag()
                } label: {
                    Label("Add Tag", systemImage: "plus")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
                .disabled(UserTagParser.normalize(draft) == nil)
                .help("Add user tag")
            }

            let tags = model.userTags(for: asset)
            if tags.isEmpty {
                Text("No custom tags yet")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(tags) { tag in
                        UserTagChip(tag: tag) {
                            model.removeUserTag(tag, from: asset)
                        }
                    }
                }
            }
        }
        .onChange(of: asset.id) {
            draft = ""
        }
    }

    private func addTag() {
        model.addUserTag(to: asset, rawValue: draft)
        draft = ""
    }
}

private struct UserTagChip: View {
    let tag: AssetTag
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            Text("\(tag.namespace):\(tag.value)")
                .lineLimit(1)

            Button(action: remove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.plain)
            .help("Remove tag")
        }
        .font(.caption2)
        .padding(.leading, 7)
        .padding(.trailing, 6)
        .padding(.vertical, 4)
        .foregroundStyle(CrateTheme.accent)
        .background(CrateTheme.accent.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: CrateTheme.chipRadius, style: .continuous))
    }
}
