//
//  CoreModelTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("Core domain models")
struct CoreModelTests {

    // MARK: - Tree traversal

    @Test("A tree flattens to all its bookmarks, depth-first")
    func treeFlattensAllBookmarks() {
        let tree = BookmarkTree.sample(for: .safari)
        // Sample: Apple, Swift, and Hacker News inside a sub-folder.
        #expect(tree.bookmarkCount == 3)
        #expect(tree.allBookmarks.map(\.title) == ["Apple", "Swift", "Hacker News"])
    }

    @Test("An empty tree has no bookmarks")
    func emptyTreeHasNoBookmarks() {
        let tree = BookmarkTree(browser: .chrome, roots: [], capturedAt: .init(timeIntervalSince1970: 0))
        #expect(tree.bookmarkCount == 0)
        #expect(tree.allBookmarks.isEmpty)
    }

    // MARK: - Node accessors

    @Test("Node exposes id, title, and folder flag")
    func nodeAccessors() {
        let bookmark = Bookmark(id: BookmarkID("b1"), title: "Example", url: URL(string: "https://example.com")!)
        let bookmarkNode = BookmarkNode.bookmark(bookmark)
        #expect(bookmarkNode.id == BookmarkID("b1"))
        #expect(bookmarkNode.title == "Example")
        #expect(bookmarkNode.isFolder == false)

        let folderNode = BookmarkNode.folder(BookmarkFolder(id: BookmarkID("f1"), title: "Folder"))
        #expect(folderNode.id == BookmarkID("f1"))
        #expect(folderNode.title == "Folder")
        #expect(folderNode.isFolder == true)
    }

    // MARK: - Browser

    @Test("Browser exposes a display name for every case")
    func browserDisplayNames() {
        #expect(Browser.safari.displayName == "Safari")
        #expect(Browser.chrome.displayName == "Google Chrome")
        #expect(Browser.allCases.count == 2)
    }

    // MARK: - Codable

    @Test("A tree survives a JSON encode/decode round-trip")
    func treeCodableRoundTrip() throws {
        let tree = BookmarkTree.sample(for: .chrome)
        let data = try JSONEncoder().encode(tree)
        let decoded = try JSONDecoder().decode(BookmarkTree.self, from: data)
        #expect(decoded == tree)
    }
}
