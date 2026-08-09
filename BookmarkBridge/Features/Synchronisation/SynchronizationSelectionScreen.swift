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
                    DocumentationText.value("selection.title"),
                    subtitle: DocumentationText.formatted(
                        "selection.subtitle",
                        direction.title
                    )
                )

                ForEach(model.sources, id: \.source.id) { source in
                    SynchronizationSummaryCard(source.source.displayName) {
                        sourceHeader(source)
                        Divider()
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(source.tree.roots) { folder in
                                SelectionTreeBranch(
                                    model: model,
                                    source: source,
                                    node: .folder(folder),
                                    depth: 0
                                )
                            }
                        }
                    }
                }

                HStack {
                    Button(
                        DocumentationText.value("action.back"),
                        action: onBack
                    )
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
                            Text(DocumentationText.value("selection.preview"))
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
        .navigationTitle(DocumentationText.value("synchronization.title"))
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: onBack) {
                    Label(
                        DocumentationText.value("action.back"),
                        systemImage: "chevron.left"
                    )
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

private struct SelectionTreeBranch: View {
    @Bindable var model: SynchronizationSelectionViewModel
    let source: SearchableSource
    let node: BookmarkNode
    let depth: Int

    var body: some View {
        if case .folder(let folder) = node, !folder.children.isEmpty {
            DisclosureGroup(
                isExpanded: Binding(
                    get: {
                        model.isExpanded(
                            folder.id,
                            in: source.source.id
                        )
                    },
                    set: {
                        model.setExpanded(
                            $0,
                            folderID: folder.id,
                            in: source.source.id
                        )
                    }
                )
            ) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(folder.children) { child in
                        SelectionTreeBranch(
                            model: model,
                            source: source,
                            node: child,
                            depth: depth + 1
                        )
                    }
                }
            } label: {
                selectionButton
            }
        } else {
            selectionButton
        }
    }

    private var selectionButton: some View {
        let selected = model.isSelected(node, in: source.source.id)
        let partial = model.isPartiallySelected(node, in: source.source.id)
        return Button {
            model.toggle(node, in: source)
        } label: {
            HStack(spacing: TreeLayout.itemSpacing) {
                TreeGuides(depth: depth)
                Image(
                    systemName: partial
                        ? "minus.square.fill"
                        : selected ? "checkmark.square.fill" : "square"
                )
                .foregroundStyle(
                    partial || selected ? Color.accentColor : .secondary
                )
                .frame(width: TreeLayout.checkboxWidth)
                .accessibilityHidden(true)
                Image(systemName: node.isFolder ? "folder" : "bookmark")
                    .foregroundStyle(.secondary)
                    .frame(width: TreeLayout.iconWidth)
                Text(
                    node.title.isEmpty
                        ? DocumentationText.value("bookmark.untitled")
                        : node.title
                )
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
        .accessibilityLabel(
            node.title.isEmpty
                ? DocumentationText.value("bookmark.untitled")
                : node.title
        )
        .accessibilityValue(
            partial
                ? DocumentationText.value("selection.partiallySelected")
                : selected
                    ? DocumentationText.value("selection.selected")
                    : DocumentationText.value("selection.notSelected")
        )
        .accessibilityHint(
            node.isFolder
                ? DocumentationText.value("selection.folder.hint")
                : DocumentationText.value("selection.bookmark.hint")
        )
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
