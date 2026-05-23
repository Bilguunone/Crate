//
//  ImportReviewView.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import SwiftUI

struct ImportReviewView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let draft = model.importReviewDraft {
            VStack(spacing: 0) {
                header(draft)
                Divider()
                content(draft)
                Divider()
                footer(draft)
            }
            .frame(width: 820, height: 650)
        }
    }

    private func header(_ draft: ImportReviewDraft) -> some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(CrateTheme.accent.opacity(0.14))
                Image(systemName: "shippingbox.and.arrow.backward")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(CrateTheme.accent)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text("Review Import")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(draft.sourceURL.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private func content(_ draft: ImportReviewDraft) -> some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                importRecipe
                Divider()
                folderSignals(draft)
            }
            .frame(width: 316, alignment: .topLeading)
            .padding(22)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    importStats(draft)
                    warnings(draft)
                    reviewDetails(draft)
                    sampleNames(draft)
                }
                .padding(22)
            }
        }
    }

    private var importRecipe: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Import Recipe")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                LabeledField(label: "Pack Name") {
                    TextField("Pack name", text: binding(\.displayName))
                }

                LabeledField(label: "Kind") {
                    Picker("Kind", selection: binding(\.kind)) {
                        Text("Texture").tag("texture")
                        Text("Overlay").tag("overlay")
                        Text("Sticker").tag("sticker")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                LabeledField(label: "Material") {
                    TextField("paper, plastic, ink...", text: binding(\.material))
                }

                LabeledField(label: "Subtype") {
                    TextField("torn-paper, lens-flare...", text: binding(\.subtype))
                }

                LabeledField(label: "Source") {
                    TextField("Resource Boy, User Import...", text: binding(\.source))
                }
            }
        }
    }

    private func folderSignals(_ draft: ImportReviewDraft) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Folder Signals")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                if draft.analysis.topLevelFolders.isEmpty {
                    Text("No subfolders")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(draft.analysis.topLevelFolders.keys.sorted().prefix(7), id: \.self) { key in
                        HStack {
                            Text(key)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text("\(draft.analysis.topLevelFolders[key] ?? 0)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .font(.caption)

            Text("Crate copies everything into the managed library. Originals stay untouched.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func importStats(_ draft: ImportReviewDraft) -> some View {
        HStack(spacing: 10) {
            ImportStatView(value: draft.analysis.imageCount, label: "Images", systemImage: "photo.on.rectangle")
            ImportStatView(value: draft.analysis.variantGroupCount, label: "Assets", systemImage: "square.grid.2x2")
            ImportStatView(value: draft.analysis.multiVariantGroupCount, label: "Variants", systemImage: "rectangle.2.swap")
            ImportStatView(value: draft.analysis.ignoredFileCount, label: "Ignored", systemImage: "nosign")
        }
    }

    @ViewBuilder
    private func warnings(_ draft: ImportReviewDraft) -> some View {
        if !draft.analysis.riskyDuplicateBasenames.isEmpty {
            ImportNoticeView(
                title: "Duplicate basenames across folders",
                message: "Crate will preserve folder context so same-named files do not collapse into one asset. Finder would absolutely let this become soup.",
                systemImage: "exclamationmark.triangle.fill",
                color: .orange
            )
        } else if draft.analysis.imageCount == 0 {
            ImportNoticeView(
                title: "No supported images",
                message: "Pick the actual pack folder with PNG, JPG, or JPEG files.",
                systemImage: "xmark.octagon.fill",
                color: .red
            )
        } else {
            ImportNoticeView(
                title: "Looks importable",
                message: "Names, tags, variants, manifest rows, and thumbnails will be created from this plan.",
                systemImage: "checkmark.seal.fill",
                color: .green
            )
        }
    }

    @ViewBuilder
    private func reviewDetails(_ draft: ImportReviewDraft) -> some View {
        if !draft.analysis.ignoredFileSamples.isEmpty || !draft.analysis.riskyDuplicateBasenames.isEmpty {
            HStack(alignment: .top, spacing: 12) {
                if !draft.analysis.ignoredFileSamples.isEmpty {
                    ImportDetailListView(
                        title: "Ignored Files",
                        items: draft.analysis.ignoredFileSamples,
                        emptyLabel: "None"
                    )
                }

                if !draft.analysis.riskyDuplicateBasenames.isEmpty {
                    ImportDetailListView(
                        title: "Duplicate Names",
                        items: Array(draft.analysis.riskyDuplicateBasenames.prefix(12)),
                        emptyLabel: "None"
                    )
                }
            }
        }
    }

    private func sampleNames(_ draft: ImportReviewDraft) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Sample Normalized Names")
                    .font(.headline)
                Spacer()
                Button {
                    model.refreshImportReview()
                } label: {
                    Label("Refresh Plan", systemImage: "arrow.clockwise")
                }
                .controlSize(.small)
            }

            VStack(spacing: 0) {
                ForEach(draft.analysis.samplePlans, id: \.assetID) { sample in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(sample.assetID)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            if sample.variantCount > 1 {
                                Text("\(sample.variantCount) variants")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text(sample.sourceFiles.prefix(2).joined(separator: ", "))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(.vertical, 8)

                    if sample.assetID != draft.analysis.samplePlans.last?.assetID {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 12)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func footer(_ draft: ImportReviewDraft) -> some View {
        HStack(spacing: 10) {
            Label("\(draft.analysis.extensionCountsSummary)", systemImage: "doc.on.doc")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            Button("Cancel") {
                model.cancelImportReview()
            }
            .keyboardShortcut(.cancelAction)

            Button {
                Task { await model.confirmImportReview() }
            } label: {
                Label("Import Pack", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(draft.analysis.imageCount == 0 || model.isImporting)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }

    private func binding(_ keyPath: WritableKeyPath<ImportReviewDraft, String>) -> Binding<String> {
        Binding {
            model.importReviewDraft?[keyPath: keyPath] ?? ""
        } set: { value in
            guard var draft = model.importReviewDraft else { return }
            draft[keyPath: keyPath] = value
            model.importReviewDraft = draft
            model.scheduleImportReviewRefresh()
        }
    }
}
