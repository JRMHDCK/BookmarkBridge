//
//  SafariBookmarkDecoderTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("SafariBookmarkDecoder")
struct SafariBookmarkDecoderTests {

    private let decoder = SafariBookmarkDecoder()
    private typealias Expected = SafariBookmarksFixture.Expected

    private func decodedTree() throws -> BookmarkTree {
        try decoder.decodeTree(from: SafariBookmarksFixture.data())
    }

    // MARK: - Recursive search helpers (order independent)

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

    @Test("Decodes into a Safari tree with the three top-level folders")
    func decodesTopLevelFolders() throws {
        let tree = try decodedTree()
        #expect(tree.browser == .safari)
        #expect(tree.roots.count == 3)
        #expect(folder(in: tree.roots, titled: Expected.bookmarksBarTitle) != nil)
        #expect(folder(in: tree.roots, titled: Expected.personalFolderTitle) != nil)
        #expect(folder(in: tree.roots, titled: Expected.readingListTitle) != nil)
    }

    @Test("Decodes the expected total number of bookmarks")
    func decodesAllBookmarks() throws {
        let tree = try decodedTree()
        // example, unicode, empty-title, mailto, swift, example.org, reading-list item
        #expect(tree.bookmarkCount == 7)
    }

    // MARK: - Bookmarks Bar & fields

    @Test("Bookmarks Bar bookmark keeps its title and URL")
    func bookmarksBarLeaf() throws {
        let tree = try decodedTree()
        let url = try #require(URL(string: Expected.exampleURL))
        let example = try #require(bookmark(in: tree, url: url))
        #expect(example.title == Expected.exampleTitle)
    }

    @Test("Preserves Unicode titles")
    func preservesUnicodeTitle() throws {
        let tree = try decodedTree()
        #expect(bookmark(in: tree, titled: Expected.unicodeTitle) != nil)
    }

    @Test("Percent-encodes Unicode URLs into valid ASCII")
    func encodesUnicodeURL() throws {
        let tree = try decodedTree()
        let node = try #require(bookmark(in: tree, titled: Expected.unicodeTitle))
        let absolute = node.url.absoluteString
        let isASCII = absolute.allSatisfy(\.isASCII)
        let hasPercentEncoding = absolute.contains("%")
        let hasRawAccent = absolute.contains("á")
        let startsWithHost = absolute.hasPrefix("https://unicode.example/")
        #expect(isASCII, "URL must be fully ASCII: \(absolute)")
        #expect(hasPercentEncoding, "URL must be percent-encoded: \(absolute)")
        #expect(!hasRawAccent)
        #expect(startsWithHost, "unexpected URL: \(absolute)")
    }

    @Test("Represents an empty title as an empty string")
    func emptyTitle() throws {
        let tree = try decodedTree()
        let url = try #require(URL(string: Expected.emptyTitleURL))
        let node = try #require(bookmark(in: tree, url: url))
        #expect(node.title == "")
    }

    @Test("Keeps an unusual (non-http) URL scheme")
    func unusualURLScheme() throws {
        let tree = try decodedTree()
        let node = try #require(tree.allBookmarks.first { $0.url.scheme == "mailto" })
        #expect(node.url.absoluteString == Expected.unusualURL)
    }

    // MARK: - Folders

    @Test("Preserves nested folders and an empty sub-folder")
    func nestedAndEmptyFolders() throws {
        let tree = try decodedTree()
        let dev = try #require(folder(in: tree.roots, titled: Expected.devFolderTitle))
        #expect(dev.allBookmarks.contains { $0.title == Expected.swiftTitle })

        let empty = try #require(folder(in: tree.roots, titled: Expected.emptyFolderTitle))
        #expect(empty.children.isEmpty)
    }

    // MARK: - Reading List

    @Test("Reading List item carries its optional DateAdded")
    func readingListDate() throws {
        let tree = try decodedTree()
        let url = try #require(URL(string: Expected.readingListURL))
        let item = try #require(bookmark(in: tree, url: url))
        #expect(item.title == Expected.readingListTitleItem)
        #expect(item.dateAdded != nil)
    }

    @Test("Bookmarks without a ReadingList entry have no dateAdded")
    func nonReadingListHasNoDate() throws {
        let tree = try decodedTree()
        let url = try #require(URL(string: Expected.exampleURL))
        let example = try #require(bookmark(in: tree, url: url))
        #expect(example.dateAdded == nil)
    }

    // MARK: - Sentinel capture time

    @Test("Leaves capturedAt at the sentinel for the reader to stamp")
    func capturedAtSentinel() throws {
        #expect(try decodedTree().capturedAt == .distantPast)
    }

    // MARK: - Robustness

    @Test("Skips only truly unrecoverable leaves (empty URL), keeps the rest")
    func skipsUnrecoverableLeaves() throws {
        let plist: [String: Any] = [
            "WebBookmarkType": "WebBookmarkTypeList",
            "Title": "",
            "Children": [
                [
                    "WebBookmarkType": "WebBookmarkTypeList",
                    "Title": "Mixed",
                    "Children": [
                        ["WebBookmarkType": "WebBookmarkTypeLeaf",
                         "URLString": "https://ok.example",
                         "URIDictionary": ["title": "OK"]],
                        // Unrecoverable: empty URL string → skipped.
                        ["WebBookmarkType": "WebBookmarkTypeLeaf",
                         "URLString": "",
                         "URIDictionary": ["title": "Broken"]],
                    ],
                ],
            ],
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
        let tree = try decoder.decodeTree(from: data)
        #expect(tree.bookmarkCount == 1)
        #expect(tree.allBookmarks.first?.title == "OK")
    }

    @Test("Throws when the data is not a property list")
    func throwsOnGarbage() {
        let garbage = Data("definitely not a plist".utf8)
        #expect(throws: BookmarkError.self) {
            try decoder.decodeTree(from: garbage)
        }
    }

    @Test("Throws when the root is not a WebBookmarkTypeList")
    func throwsOnWrongRoot() throws {
        let notAList: [String: Any] = ["WebBookmarkType": "WebBookmarkTypeLeaf", "URLString": "https://x.example"]
        let data = try PropertyListSerialization.data(fromPropertyList: notAList, format: .binary, options: 0)
        #expect(throws: BookmarkError.self) {
            try decoder.decodeTree(from: data)
        }
    }
}
