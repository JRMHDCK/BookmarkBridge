//
//  BrowserBookmarkSummary.swift
//  BookmarkBridge
//

import Foundation

/// A read-only summary of one browser's bookmarks, for display on the dashboard.
///
/// Derived from a `BookmarkTree`; carries no behaviour and never triggers I/O.
nonisolated struct BrowserBookmarkSummary: Identifiable, Hashable, Sendable {
    let browser: Browser
    let bookmarkCount: Int
    let capturedAt: Date

    var id: Browser { browser }

    init(browser: Browser, bookmarkCount: Int, capturedAt: Date) {
        self.browser = browser
        self.bookmarkCount = bookmarkCount
        self.capturedAt = capturedAt
    }

    /// Builds a summary from a captured tree.
    init(tree: BookmarkTree) {
        self.init(
            browser: tree.browser,
            bookmarkCount: tree.bookmarkCount,
            capturedAt: tree.capturedAt
        )
    }
}
