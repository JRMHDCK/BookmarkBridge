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
                            source.tree.roots.map {
                                SelectionTreeNode(
                                    node: .folder($0),
                                    depth: 0
                                )
                            },
                            children: \.outlineChildren
                        ) { item in
                            nodeRow(
                                item.node,
                                source: source,
                                depth: item.depth
                            )
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
                    size: 26
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
        source: SearchableSource,
        depth: Int
    ) -> some View {
        let selected = model.isSelected(node, in: source.source.id)
        let partial = model.isPartiallySelected(node, in: source.source.id)
        return Button {
            model.toggle(node, in: source)
        } label: {
            HStack(spacing: TreeLayout.itemSpacing) {
                TreeGuides(depth: depth)
                checkbox(
                    selected: selected,
                    partial: partial
                )
                .frame(width: TreeLayout.checkboxWidth)
                Image(systemName: node.isFolder ? "folder" : "bookmark")
                    .foregroundStyle(.secondary)
                    .frame(width: TreeLayout.iconWidth)
                Text(node.title.isEmpty ? "Sans titre" : node.title)
                    .font(
                        node.isFolder
                            ? .callout.weight(.medium)
                            : .callout
                    )
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(minHeight: TreeLayout.rowHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(node.title.isEmpty ? "Sans titre" : node.title)
        .accessibilityValue(
            partial
                ? "Partiellement sélectionné"
                : selected ? "Sélectionné" : "Non sélectionné"
        )
        .accessibilityHint(
            node.isFolder
                ? "Active ou désactive ce dossier et son contenu"
                : "Active ou désactive ce favori"
        )
    }

    private func checkbox(selected: Bool, partial: Bool) -> some View {
        Image(systemName: partial ? "minus.square.fill" : selected ? "checkmark.square.fill" : "square")
            .foregroundStyle(partial || selected ? Color.accentColor : .secondary)
            .accessibilityHidden(true)
    }
}

private enum TreeLayout {
    static let guideWidth: CGFloat = 12
    static let rowHeight: CGFloat = 30
    static let checkboxWidth: CGFloat = 16
    static let iconWidth: CGFloat = 18
    static let itemSpacing: CGFloat = Theme.Spacing.s
}

private struct SelectionTreeNode: Identifiable, Hashable {
    let node: BookmarkNode
    let depth: Int

    var id: BookmarkID { node.id }

    var outlineChildren: [SelectionTreeNode]? {
        guard case .folder(let folder) = node,
              !folder.children.isEmpty else {
            return nil
        }
        return folder.children.map {
            SelectionTreeNode(node: $0, depth: depth + 1)
        }
    }
}

private struct TreeGuides: View {
    let depth: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<depth, id: \.self) { level in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                        .offset(x: TreeLayout.guideWidth / 2)

                    if level == depth - 1 {
                        Rectangle()
                            .fill(Color(nsColor: .separatorColor))
                            .frame(
                                width: TreeLayout.guideWidth / 2,
                                height: 1
                            )
                            .offset(x: TreeLayout.guideWidth / 2)
                    }
                }
                .frame(width: TreeLayout.guideWidth)
            }
        }
        .frame(height: TreeLayout.rowHeight)
        .opacity(0.55)
        .accessibilityHidden(true)
    }
}
