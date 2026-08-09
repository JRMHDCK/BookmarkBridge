//
//  SourceExplorerView.swift
//  BookmarkBridge
//

import SwiftUI

/// Builds the destination view for one explorer navigation step, with the
/// breadcrumb bar pinned on top. Shared by the dashboard's NavigationStack and
/// the previews so the mapping lives in one place. The bound `path` lets the
/// breadcrumb truncate the navigation stack when a crumb is tapped.
@ViewBuilder
func explorerDestination(for step: ExplorerStep, path: Binding<[ExplorerStep]>) -> some View {
    explorerStepContent(for: step)
        .safeAreaInset(edge: .top, spacing: Theme.Spacing.zero) {
            BreadcrumbView(path: path)
        }
}

@ViewBuilder
private func explorerStepContent(for step: ExplorerStep) -> some View {
    switch step {
    case .source(let source, let tree):
        SourceExplorerView(source: source, tree: tree)
    case .folder(let folder):
        FolderContentsView(folder: folder)
    }
}

/// The top level of a source's read-only bookmark tree: its root folders.
struct SourceExplorerView: View {
    let source: BookmarkSource
    let tree: BookmarkTree

    var body: some View {
        FolderListView(presentation: FolderPresentation(rootsOf: tree, title: source.displayName))
            .navigationTitle(source.displayName)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    ContextualHelpButton(
                        pageID: source.browser == .safari
                            ? .safari
                            : .chrome
                    )
                }
            }
    }
}

/// The contents of one folder (its direct sub-folders and bookmarks).
struct FolderContentsView: View {
    let folder: BookmarkFolder

    var body: some View {
        let presentation = FolderPresentation(folder: folder)
        FolderListView(presentation: presentation)
            .navigationTitle(
                presentation.title.isEmpty
                    ? DocumentationText.value("folder.untitled")
                    : presentation.title
            )
    }
}

/// Renders one folder level. Folders are navigation links (drill-down);
/// bookmarks are selectable, read-only leaves showing their title and URL.
struct FolderListView: View {
    let presentation: FolderPresentation
    @State private var selection: BookmarkID?

    var body: some View {
        List(presentation.items, selection: $selection) { item in
            Group {
                switch item {
                case .folder(_, let title, let itemCount, let destination):
                    NavigationLink(value: ExplorerStep.folder(destination)) {
                        folderRow(title: title, itemCount: itemCount)
                    }
                case .bookmark(_, let title, let host, let url):
                    bookmarkRow(title: title, host: host, url: url)
                }
            }
            .tag(item.id)
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .overlay {
            if presentation.items.isEmpty {
                EmptyStateView(
                    title: DocumentationText.value("folder.empty.title"),
                    message: DocumentationText.value("folder.empty.message"),
                    systemImage: "folder"
                )
            }
        }
    }

    /// Finder-style rows use standard outline symbols and native selection.
    private func folderRow(title: String, itemCount: Int) -> some View {
        Label {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(
                    title.isEmpty
                        ? DocumentationText.value("folder.untitled")
                        : title
                )
                Text(itemCountText(itemCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "folder")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: Theme.Size.explorerIconWidth)
        }
        .frame(minHeight: Theme.Size.explorerRowMinimumHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            DocumentationText.formatted(
                "folder.accessibility",
                title.isEmpty
                    ? DocumentationText.value("folder.unnamed")
                    : title,
                itemCount
            )
        )
    }

    /// A read-only bookmark leaf: a neutral outline glyph keeps it visually
    /// quieter than the navigable folders.
    private func bookmarkRow(title: String, host: String?, url: URL) -> some View {
        let subtitle = url.absoluteString
        let displayTitle = title.isEmpty
            ? DocumentationText.value("bookmark.untitled.parenthesized")
            : title
        return Label {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(displayTitle)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
        } icon: {
            Image(systemName: "bookmark")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: Theme.Size.explorerIconWidth)
        }
        .frame(minHeight: Theme.Size.explorerRowMinimumHeight)
        .help(subtitle)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            DocumentationText.formatted(
                "bookmark.accessibility",
                displayTitle,
                host ?? subtitle
            )
        )
    }

    private func itemCountText(_ count: Int) -> String {
        DocumentationText.formatted(
            count == 1 ? "common.item.one" : "common.item.other",
            count
        )
    }
}

// MARK: - Previews

#Preview("Source") {
    NavigationStack {
        SourceExplorerView(source: .singleProfile(.safari), tree: .sample(for: .safari))
            .navigationDestination(for: ExplorerStep.self) { explorerDestination(for: $0, path: .constant([])) }
    }
    .frame(width: 460, height: 420)
    .environment(DocumentationRouter())
}

#Preview("Dossier vide") {
    NavigationStack {
        FolderContentsView(folder: BookmarkFolder(id: BookmarkID("e"), title: "Dossier vide"))
    }
    .frame(width: 460, height: 420)
}
