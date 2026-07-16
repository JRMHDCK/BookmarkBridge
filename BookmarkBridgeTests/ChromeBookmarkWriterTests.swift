//
//  ChromeBookmarkWriterTests.swift
//  BookmarkBridgeTests
//
//  Fixtures only — never touches a real Chrome file.
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("ChromeBookmarkWriter")
struct ChromeBookmarkWriterTests {

    private let writer = ChromeBookmarkWriter()
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func bookmark(_ title: String, _ url: String) -> Bookmark {
        Bookmark(id: BookmarkID(url), title: title, url: URL(string: url)!)
    }

    private func rootsObject(_ data: Data) throws -> [String: Any] {
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try #require(object["roots"] as? [String: Any])
    }

    @Test("Adds new bookmarks under Other bookmarks, preserving existing ones")
    func addsIntoOther() throws {
        let original = try ChromeBookmarksFixture.data()
        let output = try writer.applying([bookmark("New Site", "https://new.example/")], to: original, now: now)

        let tree = try ChromeBookmarkDecoder().decodeTree(from: output)
        #expect(tree.allBookmarks.contains { $0.title == "New Site" && $0.url.absoluteString == "https://new.example/" })
        #expect(tree.allBookmarks.contains { $0.title == "Example" })   // existing preserved

        let other = tree.roots.first { $0.title == ChromeBookmarksFixture.Expected.otherName }
        let hasNew = other?.children.contains { node in
            if case .bookmark(let b) = node { b.title == "New Site" } else { false }
        }
        #expect(hasNew == true)
    }

    @Test("Assigns fresh unique ids greater than any existing id")
    func assignsFreshUniqueIds() throws {
        let original = try ChromeBookmarksFixture.data()
        let output = try writer.applying(
            [bookmark("A", "https://a.example/"), bookmark("B", "https://b.example/")],
            to: original, now: now
        )
        let roots = try rootsObject(output)
        let other = try #require(roots["other"] as? [String: Any])
        let children = try #require(other["children"] as? [[String: Any]])
        let newIds = children.suffix(2).compactMap { ($0["id"] as? String).flatMap(Int64.init) }

        let allGreater = newIds.allSatisfy { $0 > 20 }   // greater than the fixture's max id (20)
        #expect(newIds.count == 2)
        #expect(Set(newIds).count == 2)                  // unique
        #expect(allGreater)
    }

    @Test("Recomputes a real, self-consistent checksum")
    func recomputesChecksum() throws {
        let original = try ChromeBookmarksFixture.data()
        let output = try writer.applying([bookmark("New", "https://new.example/")], to: original, now: now)

        let object = try #require(try JSONSerialization.jsonObject(with: output) as? [String: Any])
        let checksum = try #require(object["checksum"] as? String)
        let roots = try #require(object["roots"] as? [String: Any])

        #expect(checksum.count == 32)
        #expect(checksum != "00000000000000000000000000000000")
        #expect(checksum == ChromeChecksum.compute(roots: roots))   // matches the written tree
    }

    @Test("Output is valid Chrome JSON that re-decodes")
    func outputReDecodes() throws {
        let original = try ChromeBookmarksFixture.data()
        let output = try writer.applying([bookmark("New", "https://new.example/")], to: original, now: now)
        let tree = try ChromeBookmarkDecoder().decodeTree(from: output)
        #expect(tree.bookmarkCount > 0)
    }

    @Test("The checksum is stable for identical additions")
    func deterministicChecksum() throws {
        let original = try ChromeBookmarksFixture.data()
        let a = try writer.applying([bookmark("X", "https://x.example/")], to: original, now: now)
        let b = try writer.applying([bookmark("X", "https://x.example/")], to: original, now: now)

        let checksumA = try #require(try JSONSerialization.jsonObject(with: a) as? [String: Any])["checksum"] as? String
        let checksumB = try #require(try JSONSerialization.jsonObject(with: b) as? [String: Any])["checksum"] as? String
        #expect(checksumA == checksumB)
    }
}
