//
//  ChromeBookmarksFixtureTests.swift
//  BookmarkBridgeTests
//
//  Validates the generated Chrome fixtures at the *raw JSON* level (structure and
//  key fields). BookmarkTree-level assertions belong to the Chrome decoder step.
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("Chrome fixtures (raw JSON)")
struct ChromeBookmarksFixtureTests {

    typealias JSON = [String: Any]

    // MARK: - Navigation helpers (key/name/url based, order independent)

    private func object(_ data: Data) throws -> JSON {
        let decoded = try JSONSerialization.jsonObject(with: data)
        return try #require(decoded as? JSON, "fixture must decode to a JSON object")
    }

    private func roots(_ object: JSON) throws -> JSON {
        try #require(object["roots"] as? JSON)
    }

    private func children(of node: JSON) -> [JSON] {
        (node["children"] as? [JSON]) ?? []
    }

    private func folder(in nodes: [JSON], named name: String) -> JSON? {
        nodes.first { ($0["name"] as? String) == name && ($0["type"] as? String) == "folder" }
    }

    private func leaf(in nodes: [JSON], url: String) -> JSON? {
        nodes.first { ($0["url"] as? String) == url }
    }

    private func allLeaves(_ nodes: [JSON]) -> [JSON] {
        nodes.flatMap { node -> [JSON] in
            if (node["type"] as? String) == "url" { return [node] }
            return allLeaves(children(of: node))
        }
    }

    // MARK: - Structure

    @Test("Has version and the three roots")
    func rootsStructure() throws {
        let object = try object(try ChromeBookmarksFixture.data())
        #expect(object["version"] as? Int == 1)
        let roots = try roots(object)
        #expect(roots["bookmark_bar"] is JSON)
        #expect(roots["other"] is JSON)
        #expect(roots["synced"] is JSON)
    }

    @Test("Bookmarks bar is a folder with the expected name and children")
    func bookmarkBarFolder() throws {
        let bar = try #require(try roots(object(try ChromeBookmarksFixture.data()))["bookmark_bar"] as? JSON)
        #expect(bar["type"] as? String == "folder")
        #expect(bar["name"] as? String == ChromeBookmarksFixture.Expected.barName)
        #expect(!children(of: bar).isEmpty)
    }

    // MARK: - Leaves & fields

    @Test("A URL leaf carries type, name, url, and a Chrome date_added string")
    func urlLeafFields() throws {
        let bar = try #require(try roots(object(try ChromeBookmarksFixture.data()))["bookmark_bar"] as? JSON)
        let example = try #require(leaf(in: children(of: bar), url: ChromeBookmarksFixture.Expected.exampleURL))
        #expect(example["type"] as? String == "url")
        #expect(example["name"] as? String == ChromeBookmarksFixture.Expected.exampleName)
        #expect(example["date_added"] as? String == ChromeBookmarksFixture.Expected.dateAddedString)
    }

    @Test("Unicode name and path are preserved")
    func preservesUnicode() throws {
        let leaves = allLeaves(try roots(object(try ChromeBookmarksFixture.data())).values.compactMap { $0 as? JSON })
        let node = try #require(leaves.first { ($0["url"] as? String) == ChromeBookmarksFixture.Expected.unicodeURL })
        #expect(node["name"] as? String == ChromeBookmarksFixture.Expected.unicodeName)
    }

    @Test("Empty title is an empty string")
    func emptyTitle() throws {
        let bar = try #require(try roots(object(try ChromeBookmarksFixture.data()))["bookmark_bar"] as? JSON)
        let node = try #require(leaf(in: children(of: bar), url: ChromeBookmarksFixture.Expected.emptyTitleURL))
        #expect(node["name"] as? String == "")
    }

    @Test("An unusual (non-http) URL scheme is present")
    func unusualURL() throws {
        let allNodes = try roots(object(try ChromeBookmarksFixture.data())).values.compactMap { $0 as? JSON }
        #expect(allLeaves(allNodes).contains { ($0["url"] as? String) == ChromeBookmarksFixture.Expected.unusualURL })
    }

    // MARK: - Folders

    @Test("Nested Dev folder contains an empty sub-folder")
    func nestedEmptyFolder() throws {
        let bar = try #require(try roots(object(try ChromeBookmarksFixture.data()))["bookmark_bar"] as? JSON)
        let dev = try #require(folder(in: children(of: bar), named: ChromeBookmarksFixture.Expected.devName))
        let empty = try #require(folder(in: children(of: dev), named: ChromeBookmarksFixture.Expected.emptyFolderName))
        #expect(children(of: empty).isEmpty)
    }

    // MARK: - synced (mobile) root

    @Test("Synced root is empty by default")
    func syncedEmptyByDefault() throws {
        let synced = try #require(try roots(object(try ChromeBookmarksFixture.data()))["synced"] as? JSON)
        #expect(children(of: synced).isEmpty)
    }

    @Test("Synced root can contain an item on request")
    func syncedWithItem() throws {
        let synced = try #require(
            try roots(object(try ChromeBookmarksFixture.data(includeSyncedItem: true)))["synced"] as? JSON
        )
        #expect(children(of: synced).count == 1)
    }

    // MARK: - Determinism & anonymity

    @Test("The fixture is deterministic (identical content on every run)")
    func isDeterministic() {
        let first = ChromeBookmarksFixture.propertyList() as NSDictionary
        #expect(first.isEqual(to: ChromeBookmarksFixture.propertyList() as [AnyHashable: Any]))
    }

    @Test("The fixture contains no personal data")
    func containsNoPersonalData() throws {
        let text = String(decoding: try ChromeBookmarksFixture.data(), as: UTF8.self).lowercased()
        for token in ["jerome", "jérôme", "bricks.co", "@bricks"] {
            #expect(!text.contains(token), "fixture leaked personal token: \(token)")
        }
    }
}
