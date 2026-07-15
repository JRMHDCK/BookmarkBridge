//
//  BrowserBookmarkSummary.swift
//  BookmarkBridge
//

import Foundation

/// A read-only summary of one browser's bookmarks, for display on the dashboard.
///
/// Derived from a `BookmarkTree`; carries no behaviour and never triggers I/O.
/// The folder/node counts are computed here (a testable presentation component)
/// so the view never walks the tree itself.
nonisolated struct BrowserBookmarkSummary: Identifiable, Hashable, Sendable {
    let browser: Browser
    let folderCount: Int
    let bookmarkCount: Int
    let nodeCount: Int
    let capturedAt: Date

    var id: Browser { browser }

    init(
        browser: Browser,
        folderCount: Int,
        bookmarkCount: Int,
        nodeCount: Int,
        capturedAt: Date
    ) {
        self.browser = browser
        self.folderCount = folderCount
        self.bookmarkCount = bookmarkCount
        self.nodeCount = nodeCount
        self.capturedAt = capturedAt
    }

    /// Builds a summary from a captured tree, counting folders and total nodes.
    init(tree: BookmarkTree) {
        let folders = Self.folderCount(in: tree.roots)
        let bookmarks = tree.bookmarkCount
        self.init(
            browser: tree.browser,
            folderCount: folders,
            bookmarkCount: bookmarks,
            nodeCount: folders + bookmarks,
            capturedAt: tree.capturedAt
        )
    }

    /// Total number of folders across `roots` and their descendants.
    /// (Each root is itself a folder.)
    private static func folderCount(in roots: [BookmarkFolder]) -> Int {
        var count = 0
        func walk(_ folders: [BookmarkFolder]) {
            for folder in folders {
                count += 1
                let subFolders = folder.children.compactMap { node -> BookmarkFolder? in
                    if case .folder(let subFolder) = node { return subFolder }
                    return nil
                }
                walk(subFolders)
            }
        }
        walk(roots)
        return count
    }
}
