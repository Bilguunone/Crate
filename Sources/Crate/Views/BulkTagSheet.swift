//
//  BulkTagSheet.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import SwiftUI

struct BulkTagSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var tagText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tag \(model.selectedAssetCount) Assets")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Use `tag` or `namespace:value`.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            TextField("texture, mood:raw, project:zine", text: $tagText)
                .textFieldStyle(.roundedBorder)
                .onSubmit(applyTag)

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Apply Tag") {
                    applyTag()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(tagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
        .frame(width: 380)
    }

    private func applyTag() {
        model.addUserTagToSelection(rawValue: tagText)
        dismiss()
    }
}
