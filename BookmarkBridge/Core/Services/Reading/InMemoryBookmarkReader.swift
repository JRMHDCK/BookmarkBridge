//
//  InMemoryBookmarkReader.swift
//  BookmarkBridge
//

import Foundation

/// A `BookmarkReading` double that returns a fixed, in-memory tree.
///
/// Used for SwiftUI previews, unit tests, and to keep the app runnable during
/// the read-only bootstrapping phase — before any real Safari/Chrome reader
/// exists. It performs **no file access**.
nonisolated struct InMemoryBookmarkReader: BookmarkReading {
    let browser: Browser
    private let tree: BookmarkTree

    init(browser: Browser, tree: BookmarkTree) {
        self.browser = browser
        self.tree = tree
    }

    func readBookmarkTree() async throws -> BookmarkTree {
        tree
    }
}

extension BookmarkTree {
    /// A small, deterministic sample tree for previews and tests.
    ///
    /// `capturedAt` is fixed (epoch) so equality and snapshots stay stable.
    nonisolated static func sample(for browser: Browser) -> BookmarkTree {
        let prefix = browser.rawValue
        let bar = BookmarkFolder(
            id: BookmarkID("\(prefix).bar"),
            title: "Bookmarks Bar",
            children: [
                .bookmark(Bookmark(
                    id: BookmarkID("\(prefix).apple"),
                    title: "Apple",
                    url: URL(string: "https://www.apple.com")!
                )),
                .bookmark(Bookmark(
                    id: BookmarkID("\(prefix).swift"),
                    title: "Swift",
                    url: URL(string: "https://www.swift.org")!
                )),
                .folder(BookmarkFolder(
                    id: BookmarkID("\(prefix).news"),
                    title: "News",
                    children: [
                        .bookmark(Bookmark(
                            id: BookmarkID("\(prefix).hn"),
                            title: "Hacker News",
                            url: URL(string: "https://news.ycombinator.com")!
                        ))
                    ]
                )),
            ]
        )
        return BookmarkTree(
            browser: browser,
            roots: [bar],
            capturedAt: Date(timeIntervalSince1970: 0)
        )
    }
}
