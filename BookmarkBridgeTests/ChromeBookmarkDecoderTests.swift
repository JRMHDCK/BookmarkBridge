//
//  ChromeBookmarkDecoderTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("ChromeBookmarkDecoder")
struct ChromeBookmarkDecoderTests {

    private let decoder = ChromeBookmarkDecoder()
    private typealias Expected = ChromeBookmarksFixture.Expected

    private func decodedTree(includeSyncedItem: Bool = false) throws -> BookmarkTree {
        try decoder.decodeTree(from: ChromeBookmarksFixture.data(includeSyncedItem: includeSyncedItem))
    }

    // MARK: - Recursive search helpers

    private func folder(in folders: [BookmarkFolder], titled title: String) -> BookmarkFolder? {
        for folder in folders {
            if folder.title == title { return folder }
            let nested = folder.children.compactMap { node -> BookmarkFolder? in
                if case .folder(let sub) = node { return sub }
                return nil
            }
            if let found = self.folder(in: nested, titled: title) { return found }
        }
        return nil
    }

    private func bookmark(in tree: BookmarkTree, url: URL) -> Bookmark? {
        tree.allBookmarks.first { $0.url == url }
    }

    private func bookmark(in tree: BookmarkTree, titled title: String) -> Bookmark? {
        tree.allBookmarks.first { $0.title == title }
    }

    // MARK: - Structure

    @Test("Decodes a Chrome tree with bookmark_bar and other (synced excluded when empty)")
    func decodesRoots() throws {
        let tree = try decodedTree()
        #expect(tree.browser == .chrome)
        #expect(tree.roots.map(\.title) == [Expected.barName, Expected.otherName])
    }

    @Test("Decodes the expected total number of bookmarks")
    func decodesBookmarkCount() throws {
        // bar: example, unicode, empty-title, mailto, swift (5) + other: example.org (1)
        #expect(try decodedTree().bookmarkCount == 6)
    }

    // MARK: - synced (mobile) root

    @Test("Excludes the synced root when it is empty")
    func excludesEmptySynced() throws {
        let tree = try decodedTree()
        #expect(tree.roots.count == 2)
        #expect(folder(in: tree.roots, titled: Expected.syncedName) == nil)
    }

    @Test("Includes the synced root when it has items")
    func includesNonEmptySynced() throws {
        let tree = try decodedTree(includeSyncedItem: true)
        #expect(tree.roots.count == 3)
        #expect(folder(in: tree.roots, titled: Expected.syncedName) != nil)
        #expect(tree.bookmarkCount == 7)
    }

    // MARK: - Fields

    @Test("A bookmark keeps its title, URL, and converted Chrome date")
    func bookmarkFields() throws {
        let tree = try decodedTree()
        let url = try #require(URL(string: Expected.exampleURL))
        let example = try #require(bookmark(in: tree, url: url))
        #expect(example.title == Expected.exampleName)
        // 2023-01-01T00:00:00Z
        #expect(example.dateAdded == Date(timeIntervalSince1970: 1_672_531_200))
    }

    @Test("Preserves Unicode titles and percent-encodes Unicode URLs")
    func unicode() throws {
        let tree = try decodedTree()
        let node = try #require(bookmark(in: tree, titled: Expected.unicodeName))
        let absolute = node.url.absoluteString
        let isASCII = absolute.allSatisfy(\.isASCII)
        let encoded = absolute.contains("%")
        #expect(isASCII, "URL must be ASCII: \(absolute)")
        #expect(encoded, "URL must be percent-encoded: \(absolute)")
    }

    @Test("Represents an empty title as an empty string")
    func emptyTitle() throws {
        let tree = try decodedTree()
        let url = try #require(URL(string: Expected.emptyTitleURL))
        let node = try #require(bookmark(in: tree, url: url))
        #expect(node.title == "")
    }

    @Test("Keeps an unusual (non-http) URL scheme")
    func unusualScheme() throws {
        let tree = try decodedTree()
        let node = try #require(tree.allBookmarks.first { $0.url.scheme == "mailto" })
        #expect(node.url.absoluteString == Expected.unusualURL)
    }

    // MARK: - Folders

    @Test("Preserves nested folders and an empty sub-folder")
    func nestedFolders() throws {
        let tree = try decodedTree()
        let dev = try #require(folder(in: tree.roots, titled: Expected.devName))
        #expect(dev.allBookmarks.contains { $0.title == Expected.swiftName })
        let empty = try #require(folder(in: tree.roots, titled: Expected.emptyFolderName))
        #expect(empty.children.isEmpty)
    }

    // MARK: - Sentinel capture time

    @Test("Leaves capturedAt at the sentinel for the reader to stamp")
    func capturedAtSentinel() throws {
        #expect(try decodedTree().capturedAt == .distantPast)
    }

    // MARK: - Chrome timestamp conversion

    @Test("Converts Chrome microseconds-since-1601 to a Date")
    func chromeDateConversion() {
        #expect(ChromeBookmarkDecoder.date(fromChromeTimestamp: "13317004800000000")
                == Date(timeIntervalSince1970: 1_672_531_200))
        #expect(ChromeBookmarkDecoder.date(fromChromeTimestamp: "0") == nil)
        #expect(ChromeBookmarkDecoder.date(fromChromeTimestamp: "not-a-number") == nil)
    }

    // MARK: - Robustness

    @Test("Skips only truly unrecoverable leaves (empty URL), keeps the rest")
    func skipsUnrecoverableLeaves() throws {
        let json: [String: Any] = [
            "version": 1,
            "roots": [
                "bookmark_bar": [
                    "type": "folder", "id": "1", "name": "Bar",
                    "children": [
                        ["type": "url", "id": "2", "name": "OK", "url": "https://ok.example"],
                        ["type": "url", "id": "3", "name": "Broken", "url": ""],
                    ],
                ],
                "other": ["type": "folder", "id": "4", "name": "Other", "children": []],
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let tree = try decoder.decodeTree(from: data)
        #expect(tree.bookmarkCount == 1)
        #expect(tree.allBookmarks.first?.title == "OK")
    }

    @Test("Throws when the data is not JSON")
    func throwsOnGarbage() {
        #expect(throws: BookmarkError.self) {
            try decoder.decodeTree(from: Data("definitely not json".utf8))
        }
    }

    @Test("Throws when the roots object is missing")
    func throwsOnMissingRoots() throws {
        let data = try JSONSerialization.data(withJSONObject: ["version": 1])
        #expect(throws: BookmarkError.self) {
            try decoder.decodeTree(from: data)
        }
    }
}
