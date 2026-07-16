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
        .safeAreaInset(edge: .top, spacing: 0) {
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
    }
}

/// The contents of one folder (its direct sub-folders and bookmarks).
struct FolderContentsView: View {
    let folder: BookmarkFolder

    var body: some View {
        let presentation = FolderPresentation(folder: folder)
        FolderListView(presentation: presentation)
            .navigationTitle(presentation.title.isEmpty ? "Dossier" : presentation.title)
    }
}

/// Renders one folder level. Folders are navigation links (drill-down);
/// bookmarks are read-only leaves showing their title and host/URL.
struct FolderListView: View {
    let presentation: FolderPresentation

    var body: some View {
        List(presentation.items) { item in
            switch item {
            case .folder(_, let title, let itemCount, let destination):
                NavigationLink(value: ExplorerStep.folder(destination)) {
                    folderRow(title: title, itemCount: itemCount)
                }
            case .bookmark(_, let title, let host, let url):
                bookmarkRow(title: title, host: host, url: url)
            }
        }
        .listStyle(.inset)
        .overlay {
            if presentation.items.isEmpty {
                ContentUnavailableView("Dossier vide", systemImage: "folder")
            }
        }
    }

    /// A navigable folder: a filled, brand-blue glyph makes drill-down targets
    /// stand out from the neutral bookmark leaves.
    private func folderRow(title: String, itemCount: Int) -> some View {
        Label {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title.isEmpty ? "Dossier" : title)
                Text("^[\(itemCount) élément](inflect: true)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "folder.fill")
                .foregroundStyle(Theme.Palette.blue)
        }
        .padding(.vertical, Theme.Spacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Dossier \(title.isEmpty ? "sans nom" : title), \(itemCount) élément(s)")
    }

    /// A read-only bookmark leaf: a neutral outline glyph keeps it visually
    /// quieter than the navigable folders.
    private func bookmarkRow(title: String, host: String?, url: URL) -> some View {
        let subtitle = host ?? url.absoluteString
        let displayTitle = title.isEmpty ? "(Sans titre)" : title
        return Label {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(displayTitle)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        } icon: {
            Image(systemName: "bookmark")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, Theme.Spacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Favori \(displayTitle), \(subtitle)")
    }
}

// MARK: - Previews

#Preview("Source") {
    NavigationStack {
        SourceExplorerView(source: .singleProfile(.safari), tree: .sample(for: .safari))
            .navigationDestination(for: ExplorerStep.self) { explorerDestination(for: $0, path: .constant([])) }
    }
    .frame(width: 460, height: 420)
}

#Preview("Dossier vide") {
    NavigationStack {
        FolderContentsView(folder: BookmarkFolder(id: BookmarkID("e"), title: "Dossier vide"))
    }
    .frame(width: 460, height: 420)
}
