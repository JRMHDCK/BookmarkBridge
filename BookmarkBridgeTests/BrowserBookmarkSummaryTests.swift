//
//  BrowserBookmarkSummaryTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("BrowserBookmarkSummary")
struct BrowserBookmarkSummaryTests {

    @Test("Counts folders, bookmarks, and total nodes from the fixture tree")
    func countsFromFixture() throws {
        let tree = try SafariBookmarkDecoder().decodeTree(from: SafariBookmarksFixture.data())
        let summary = BrowserBookmarkSummary(tree: tree)

        // Roots (BookmarksBar, Personnel, ReadingList) + nested Dev + empty folder = 5.
        #expect(summary.folderCount == 5)
        #expect(summary.bookmarkCount == 7)
        #expect(summary.nodeCount == 12)
        #expect(summary.browser == .safari)
        #expect(summary.capturedAt == tree.capturedAt)
    }

    @Test("Reports zero counts for an empty tree")
    func emptyTree() {
        let tree = BookmarkTree(browser: .safari, roots: [], capturedAt: .distantPast)
        let summary = BrowserBookmarkSummary(tree: tree)

        #expect(summary.folderCount == 0)
        #expect(summary.bookmarkCount == 0)
        #expect(summary.nodeCount == 0)
    }

    @Test("Counts nested folders and their bookmarks")
    func countsNestedFolders() throws {
        let urlA = try #require(URL(string: "https://a.example"))
        let urlB = try #require(URL(string: "https://b.example"))
        let tree = BookmarkTree(
            browser: .chrome,
            roots: [
                BookmarkFolder(id: BookmarkID("bar"), title: "Bar", children: [
                    .bookmark(Bookmark(id: BookmarkID("a"), title: "A", url: urlA)),
                    .folder(BookmarkFolder(id: BookmarkID("sub"), title: "Sub", children: [
                        .bookmark(Bookmark(id: BookmarkID("b"), title: "B", url: urlB)),
                    ])),
                ]),
            ],
            capturedAt: .distantPast
        )
        let summary = BrowserBookmarkSummary(tree: tree)

        #expect(summary.folderCount == 2)   // Bar + Sub
        #expect(summary.bookmarkCount == 2) // A + B
        #expect(summary.nodeCount == 4)
    }
}
