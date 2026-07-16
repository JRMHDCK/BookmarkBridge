//
//  FolderPresentationTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("FolderPresentation")
struct FolderPresentationTests {

    private func url(_ string: String) throws -> URL {
        try #require(URL(string: string))
    }

    // MARK: - Folder contents

    @Test("Maps a folder's direct children, preserving order")
    func mapsChildrenInOrder() throws {
        let appleURL = try url("https://www.apple.com/")
        let swiftURL = try url("https://swift.org/")
        let dev = BookmarkFolder(id: BookmarkID("dev"), title: "Dev", children: [
            .bookmark(Bookmark(id: BookmarkID("swift"), title: "Swift", url: swiftURL)),
        ])
        let bar = BookmarkFolder(id: BookmarkID("bar"), title: "Bar", children: [
            .bookmark(Bookmark(id: BookmarkID("apple"), title: "Apple", url: appleURL)),
            .folder(dev),
        ])

        let presentation = FolderPresentation(folder: bar)

        #expect(presentation.title == "Bar")
        #expect(presentation.items.count == 2)

        guard case .bookmark(let id0, let title0, let host0, let url0) = presentation.items[0] else {
            Issue.record("item 0 should be a bookmark")
            return
        }
        #expect(id0 == BookmarkID("apple"))
        #expect(title0 == "Apple")
        #expect(host0 == "www.apple.com")
        #expect(url0 == appleURL)

        guard case .folder(let id1, let title1, let count1, let destination1) = presentation.items[1] else {
            Issue.record("item 1 should be a folder")
            return
        }
        #expect(id1 == BookmarkID("dev"))
        #expect(title1 == "Dev")
        #expect(count1 == 1)
        #expect(destination1 == dev)
    }

    @Test("An empty folder maps to no items")
    func emptyFolder() {
        let empty = BookmarkFolder(id: BookmarkID("e"), title: "Vide", children: [])
        let presentation = FolderPresentation(folder: empty)
        #expect(presentation.title == "Vide")
        #expect(presentation.items.isEmpty)
    }

    @Test("A URL without a host (e.g. mailto) yields a nil host")
    func hostlessURL() throws {
        let mailto = try url("mailto:contact@example.org")
        let folder = BookmarkFolder(id: BookmarkID("f"), title: "F", children: [
            .bookmark(Bookmark(id: BookmarkID("m"), title: "Contact", url: mailto)),
        ])

        let presentation = FolderPresentation(folder: folder)

        guard case .bookmark(_, _, let host, _) = presentation.items[0] else {
            Issue.record("expected a bookmark")
            return
        }
        #expect(host == nil)
    }

    @Test("Item id reflects the underlying node id")
    func itemIdentity() throws {
        let folder = BookmarkFolder(id: BookmarkID("f"), title: "F", children: [
            .bookmark(Bookmark(id: BookmarkID("b"), title: "B", url: try url("https://b.example/"))),
        ])
        #expect(FolderPresentation(folder: folder).items.first?.id == BookmarkID("b"))
    }

    // MARK: - Source roots

    @Test("Maps a source's roots to navigable folder items")
    func mapsRoots() throws {
        let bar = BookmarkFolder(id: BookmarkID("bar"), title: "Bookmarks Bar", children: [
            .bookmark(Bookmark(id: BookmarkID("x"), title: "X", url: try url("https://x.example/"))),
        ])
        let other = BookmarkFolder(id: BookmarkID("other"), title: "Other", children: [])
        let tree = BookmarkTree(browser: .safari, roots: [bar, other], capturedAt: .distantPast)

        let presentation = FolderPresentation(rootsOf: tree, title: "Safari")

        #expect(presentation.title == "Safari")
        #expect(presentation.items.count == 2)
        guard case .folder(let id0, let title0, let count0, _) = presentation.items[0] else {
            Issue.record("root 0 should be a folder")
            return
        }
        #expect(id0 == BookmarkID("bar"))
        #expect(title0 == "Bookmarks Bar")
        #expect(count0 == 1)
    }
}
