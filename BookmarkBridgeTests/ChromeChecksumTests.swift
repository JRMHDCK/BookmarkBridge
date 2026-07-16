//
//  ChromeChecksumTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("ChromeChecksum")
struct ChromeChecksumTests {

    private func fixtureRoots() throws -> [String: Any] {
        let object = try #require(try JSONSerialization.jsonObject(with: ChromeBookmarksFixture.data()) as? [String: Any])
        return try #require(object["roots"] as? [String: Any])
    }

    @Test("Produces a 32-character lowercase hex digest")
    func format() throws {
        let checksum = ChromeChecksum.compute(roots: try fixtureRoots())
        let isHex = checksum.allSatisfy(\.isHexDigit)
        #expect(checksum.count == 32)
        #expect(isHex)
        #expect(checksum == checksum.lowercased())
    }

    @Test("Is deterministic for the same tree")
    func deterministic() throws {
        let roots = try fixtureRoots()
        #expect(ChromeChecksum.compute(roots: roots) == ChromeChecksum.compute(roots: roots))
    }

    @Test("Changes when the tree content changes")
    func changesWithContent() throws {
        var roots = try fixtureRoots()
        let before = ChromeChecksum.compute(roots: roots)

        // Add a URL node to "other" and expect a different digest.
        var other = try #require(roots["other"] as? [String: Any])
        var children = try #require(other["children"] as? [[String: Any]])
        children.append(["type": "url", "id": "999", "name": "Z", "url": "https://z.example/"])
        other["children"] = children
        roots["other"] = other

        #expect(ChromeChecksum.compute(roots: roots) != before)
    }
}
