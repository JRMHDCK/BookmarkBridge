//
//  SourceExplorerView.swift
//  BookmarkBridge
//

import SwiftUI

/// A drill-down navigation value opening a source's bookmark tree. Carries the
/// tree by value so the pushed explorer is stable across dashboard reloads.
nonisolated struct ExplorerRoute: Hashable, Sendable {
    let source: BookmarkSource
    let tree: BookmarkTree
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
        FolderListView(presentation: FolderPresentation(folder: folder))
            .navigationTitle(folder.title.isEmpty ? "Dossier" : folder.title)
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
                NavigationLink(value: destination) {
                    folderRow(title: title, itemCount: itemCount)
                }
            case .bookmark(_, let title, let host, let url):
                bookmarkRow(title: title, host: host, url: url)
            }
        }
        .overlay {
            if presentation.items.isEmpty {
                ContentUnavailableView("Dossier vide", systemImage: "folder")
            }
        }
    }

    private func folderRow(title: String, itemCount: Int) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.isEmpty ? "Dossier" : title)
                Text("^[\(itemCount) élément](inflect: true)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "folder")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Dossier \(title.isEmpty ? "sans nom" : title), \(itemCount) élément(s)")
    }

    private func bookmarkRow(title: String, host: String?, url: URL) -> some View {
        let subtitle = host ?? url.absoluteString
        let displayTitle = title.isEmpty ? "(Sans titre)" : title
        return Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(displayTitle)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        } icon: {
            Image(systemName: "bookmark")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Favori \(displayTitle), \(subtitle)")
    }
}

// MARK: - Previews

#Preview("Source") {
    NavigationStack {
        SourceExplorerView(source: .singleProfile(.safari), tree: .sample(for: .safari))
            .navigationDestination(for: BookmarkFolder.self) { FolderContentsView(folder: $0) }
    }
    .frame(width: 460, height: 420)
}

#Preview("Dossier vide") {
    NavigationStack {
        FolderContentsView(folder: BookmarkFolder(id: BookmarkID("e"), title: "Dossier vide"))
    }
    .frame(width: 460, height: 420)
}
