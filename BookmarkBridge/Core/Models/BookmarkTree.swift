//
//  BookmarkTree.swift
//  BookmarkBridge
//

import Foundation

/// An immutable snapshot of a browser's bookmarks at a point in time.
///
/// `roots` are the top-level folders a browser exposes (e.g. the Bookmarks Bar
/// and Other Bookmarks). A tree is a pure value: reading a browser produces one,
/// and diffing compares two of them — never any side effects.
nonisolated struct BookmarkTree: Hashable, Sendable, Codable {
    let browser: Browser
    let roots: [BookmarkFolder]
    let capturedAt: Date

    init(browser: Browser, roots: [BookmarkFolder], capturedAt: Date) {
        self.browser = browser
        self.roots = roots
        self.capturedAt = capturedAt
    }

    /// Every bookmark in the tree, depth-first. Useful for counts and diffing.
    var allBookmarks: [Bookmark] {
        roots.flatMap(\.allBookmarks)
    }

    /// Total number of bookmarks (folders excluded).
    var bookmarkCount: Int {
        allBookmarks.count
    }
}
