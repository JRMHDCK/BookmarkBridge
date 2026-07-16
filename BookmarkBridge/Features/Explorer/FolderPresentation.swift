//
//  FolderPresentation.swift
//  BookmarkBridge
//

import Foundation

/// One displayable row inside a folder: either a sub-folder (navigable) or a
/// bookmark (a leaf). Display fields are precomputed so the view never walks the
/// tree; `destination` carries the sub-folder for drill-down navigation.
nonisolated enum FolderItemPresentation: Identifiable, Equatable, Sendable {
    case folder(id: BookmarkID, title: String, itemCount: Int, destination: BookmarkFolder)
    case bookmark(id: BookmarkID, title: String, host: String?, url: URL)

    var id: BookmarkID {
        switch self {
        case .folder(let id, _, _, _): id
        case .bookmark(let id, _, _, _): id
        }
    }
}

/// One level of a bookmark hierarchy, ready to display: a title and its ordered
/// items. Built by a testable mapper from the immutable Core tree — read-only,
/// one depth at a time (no recursion in the view).
nonisolated struct FolderPresentation: Equatable, Sendable {
    let title: String
    let items: [FolderItemPresentation]

    init(title: String, items: [FolderItemPresentation]) {
        self.title = title
        self.items = items
    }

    /// The contents of a folder (its direct children), for display.
    init(folder: BookmarkFolder) {
        self.init(title: Self.displayTitle(folder.title), items: Self.items(of: folder.children))
    }

    /// The top level of a source: its root folders, under a given title.
    init(rootsOf tree: BookmarkTree, title: String) {
        let items = tree.roots.map { root in
            FolderItemPresentation.folder(
                id: root.id,
                title: Self.displayTitle(root.title),
                itemCount: root.children.count,
                destination: root
            )
        }
        self.init(title: title, items: items)
    }

    private static func items(of nodes: [BookmarkNode]) -> [FolderItemPresentation] {
        nodes.map { node in
            switch node {
            case .folder(let folder):
                .folder(
                    id: folder.id,
                    title: displayTitle(folder.title),
                    itemCount: folder.children.count,
                    destination: folder
                )
            case .bookmark(let bookmark):
                .bookmark(
                    id: bookmark.id,
                    title: bookmark.title,
                    host: bookmark.url.host(),
                    url: bookmark.url
                )
            }
        }
    }

    /// Maps a folder's technical title to its human-readable name (shared with
    /// global search via `FolderTitleFormatter`). Any other title is unchanged.
    static func displayTitle(_ rawTitle: String) -> String {
        FolderTitleFormatter.friendly(rawTitle)
    }
}
