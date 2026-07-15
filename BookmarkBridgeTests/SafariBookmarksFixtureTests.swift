//
//  SafariBookmarksFixtureTests.swift
//  BookmarkBridgeTests
//
//  Validates the programmatically generated Safari fixture at the *raw
//  property-list* level (structure and key fields). BookmarkTree-level
//  assertions belong to the Safari decoder sub-step, since the decoder is what
//  produces a BookmarkTree.
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("Safari fixture (raw property list)")
struct SafariBookmarksFixtureTests {

    typealias PList = [String: Any]

    // MARK: - Navigation helpers (dictionary-order independent)

    private func children(of node: PList) -> [PList] {
        (node["Children"] as? [PList]) ?? []
    }

    private func type(of node: PList) -> String? {
        node["WebBookmarkType"] as? String
    }

    private func list(in nodes: [PList], titled title: String) -> PList? {
        nodes.first { ($0["Title"] as? String) == title && type(of: $0) == "WebBookmarkTypeList" }
    }

    private func leaf(in nodes: [PList], url: String) -> PList? {
        nodes.first { ($0["URLString"] as? String) == url }
    }

    private func leafTitle(_ leaf: PList) -> String? {
        (leaf["URIDictionary"] as? PList)?["title"] as? String
    }

    private func root() throws -> PList {
        let data = try SafariBookmarksFixture.data()
        let object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        return try #require(object as? PList, "fixture must decode to a dictionary")
    }

    private func allLeaves(_ nodes: [PList]) -> [PList] {
        nodes.flatMap { node -> [PList] in
            if type(of: node) == "WebBookmarkTypeLeaf" { return [node] }
            return allLeaves(children(of: node))
        }
    }

    // MARK: - Structure

    @Test("Root is a WebBookmarkTypeList")
    func rootIsList() throws {
        let root = try root()
        #expect(type(of: root) == "WebBookmarkTypeList")
        #expect(!children(of: root).isEmpty)
    }

    @Test("Root exposes the Bookmarks Bar, a personal folder, and the Reading List")
    func rootTopLevelSections() throws {
        let top = children(of: try root())
        #expect(list(in: top, titled: SafariBookmarksFixture.Expected.bookmarksBarTitle) != nil)
        #expect(list(in: top, titled: SafariBookmarksFixture.Expected.personalFolderTitle) != nil)
        #expect(list(in: top, titled: SafariBookmarksFixture.Expected.readingListTitle) != nil)
    }

    // MARK: - Bookmarks & fields

    @Test("Bookmarks Bar contains the example bookmark with its title")
    func bookmarksBarHasExample() throws {
        let top = children(of: try root())
        let bar = try #require(list(in: top, titled: SafariBookmarksFixture.Expected.bookmarksBarTitle))
        let example = try #require(leaf(in: children(of: bar), url: SafariBookmarksFixture.Expected.exampleURL))
        #expect(leafTitle(example) == SafariBookmarksFixture.Expected.exampleTitle)
    }

    @Test("Unicode titles and paths are preserved")
    func preservesUnicode() throws {
        let top = children(of: try root())
        let bar = try #require(list(in: top, titled: SafariBookmarksFixture.Expected.bookmarksBarTitle))
        let node = try #require(leaf(in: children(of: bar), url: SafariBookmarksFixture.Expected.unicodeURL))
        #expect(leafTitle(node) == SafariBookmarksFixture.Expected.unicodeTitle)
    }

    @Test("An empty title is represented as an empty string")
    func supportsEmptyTitle() throws {
        let top = children(of: try root())
        let bar = try #require(list(in: top, titled: SafariBookmarksFixture.Expected.bookmarksBarTitle))
        let node = try #require(leaf(in: children(of: bar), url: SafariBookmarksFixture.Expected.emptyTitleURL))
        #expect(leafTitle(node) == "")
    }

    @Test("An unusual (non-http) URL scheme is present")
    func supportsUnusualURL() throws {
        let leaves = allLeaves(children(of: try root()))
        #expect(leaves.contains { ($0["URLString"] as? String) == SafariBookmarksFixture.Expected.unusualURL })
    }

    // MARK: - Folders

    @Test("Nested Dev folder contains an empty sub-folder")
    func containsEmptyNestedFolder() throws {
        let top = children(of: try root())
        let bar = try #require(list(in: top, titled: SafariBookmarksFixture.Expected.bookmarksBarTitle))
        let dev = try #require(list(in: children(of: bar), titled: SafariBookmarksFixture.Expected.devFolderTitle))
        let empty = try #require(list(in: children(of: dev), titled: SafariBookmarksFixture.Expected.emptyFolderTitle))
        #expect(children(of: empty).isEmpty)
    }

    // MARK: - Reading List

    @Test("Reading List contains an item with ReadingList metadata")
    func readingListItem() throws {
        let top = children(of: try root())
        let readingList = try #require(list(in: top, titled: SafariBookmarksFixture.Expected.readingListTitle))
        let item = try #require(leaf(in: children(of: readingList), url: SafariBookmarksFixture.Expected.readingListURL))
        #expect(leafTitle(item) == SafariBookmarksFixture.Expected.readingListTitleItem)
        #expect(item["ReadingList"] is PList)
    }

    // MARK: - Determinism & anonymity

    @Test("The fixture is deterministic (identical content on every run)")
    func isDeterministic() {
        let first = SafariBookmarksFixture.propertyList() as NSDictionary
        let second = SafariBookmarksFixture.propertyList() as NSDictionary
        #expect(first.isEqual(to: second as! [AnyHashable: Any]))
    }

    @Test("The fixture contains no personal data")
    func containsNoPersonalData() throws {
        let data = try SafariBookmarksFixture.data()
        let asText = String(decoding: data, as: UTF8.self).lowercased()
        for token in ["jerome", "bricks.co", "@bricks"] {
            #expect(!asText.contains(token), "fixture leaked personal token: \(token)")
        }
    }
}
