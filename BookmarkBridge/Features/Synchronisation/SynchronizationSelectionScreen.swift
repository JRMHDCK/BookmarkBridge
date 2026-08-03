//
//  SynchronizationSelectionScreen.swift
//  BookmarkBridge
//

import SwiftUI

struct SynchronizationSelectionScreen: View {
    let model: SynchronizationSelectionViewModel
    let direction: SynchronizationDirectionOption
    let onContinue: @MainActor () async -> Void
    let onBack: () -> Void

    @State private var isLoadingPreview = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                ScreenHeader(
                    "Éléments à synchroniser",
                    subtitle: "Choisissez les profils, dossiers et favoris inclus dans \(direction.title.lowercased())."
                )

                ForEach(model.sources, id: \.source.id) { source in
                    SynchronizationSummaryCard(source.source.displayName) {
                        sourceHeader(source)
                        Divider()
                        OutlineGroup(
                            source.tree.roots.map(BookmarkNode.folder),
                            children: \.outlineChildren
                        ) { node in
                            nodeRow(node, source: source)
                        }
                    }
                }

                HStack {
                    Button("Retour", action: onBack)
                    Spacer()
                    Button {
                        isLoadingPreview = true
                        Task {
                            await onContinue()
                            isLoadingPreview = false
                        }
                    } label: {
                        if isLoadingPreview {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Afficher l’aperçu")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoadingPreview || !model.canPreview)
                    .accessibilityIdentifier("synchronization-selection-continue")
                }
            }
            .frame(maxWidth: Theme.Size.contentMaxWidth, alignment: .leading)
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .navigationTitle("Synchronisation")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: onBack) {
                    Label("Retour", systemImage: "chevron.left")
                }
                .disabled(isLoadingPreview)
            }
            ToolbarItem(placement: .primaryAction) {
                ContextualHelpButton(pageID: .synchronization)
            }
        }
    }

    private func sourceHeader(_ source: SearchableSource) -> some View {
        Button {
            model.toggleSource(source)
        } label: {
            HStack(spacing: Theme.Spacing.s) {
                checkbox(
                    selected: model.sourceIsSelected(source),
                    partial: model.sourceIsPartiallySelected(source)
                )
                BrowserLogo(
                    browser: source.source.browser,
                    size: 26,
                    chromeArtwork: .homeAndSynchronization
                )
                Text(source.source.displayName)
                    .font(.headline)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("selection-source-\(source.source.id.profile ?? source.source.browser.displayName)")
    }

    private func nodeRow(
        _ node: BookmarkNode,
        source: SearchableSource
    ) -> some View {
        Button {
            model.toggle(node, in: source)
        } label: {
            HStack(spacing: Theme.Spacing.s) {
                checkbox(
                    selected: model.isSelected(node, in: source.source.id),
                    partial: model.isPartiallySelected(node, in: source.source.id)
                )
                Image(systemName: node.isFolder ? "folder" : "bookmark")
                    .foregroundStyle(.secondary)
                Text(node.title.isEmpty ? "Sans titre" : node.title)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func checkbox(selected: Bool, partial: Bool) -> some View {
        Image(systemName: partial ? "minus.square.fill" : selected ? "checkmark.square.fill" : "square")
            .foregroundStyle(partial || selected ? Color.accentColor : .secondary)
            .accessibilityHidden(true)
    }
}

private extension BookmarkNode {
    var outlineChildren: [BookmarkNode]? {
        guard case .folder(let folder) = self, !folder.children.isEmpty else {
            return nil
        }
        return folder.children
    }
}
