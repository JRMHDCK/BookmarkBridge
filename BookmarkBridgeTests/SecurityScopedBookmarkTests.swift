//
//  SecurityScopedBookmarkTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("Security-scoped bookmark creating & resolving")
struct SecurityScopedBookmarkTests {

    private struct Boom: Error {}

    private func url(_ path: String) -> URL { URL(fileURLWithPath: path) }

    // MARK: - ResolvedBookmark value

    @Test("ResolvedBookmark compares by url and staleness")
    func resolvedBookmarkEquality() {
        let a = ResolvedBookmark(url: url("/tmp/a"), isStale: false)
        #expect(a == ResolvedBookmark(url: url("/tmp/a"), isStale: false))
        #expect(a != ResolvedBookmark(url: url("/tmp/a"), isStale: true))
        #expect(a != ResolvedBookmark(url: url("/tmp/b"), isStale: false))
    }

    // MARK: - Creator double

    @Test("StubBookmarkCreator returns data and records the requested URL")
    func creatorDoubleSuccess() throws {
        let creator = StubBookmarkCreator(.success(Data([0x01, 0x02])))
        let data = try creator.makeBookmark(for: url("/tmp/Bookmarks.plist"))
        #expect(data == Data([0x01, 0x02]))
        #expect(creator.requestedURLs.map { $0.path(percentEncoded: false) } == ["/tmp/Bookmarks.plist"])
    }

    @Test("StubBookmarkCreator propagates a configured error")
    func creatorDoubleFailure() {
        let creator = StubBookmarkCreator(.failure(Boom()))
        #expect(throws: Boom.self) {
            _ = try creator.makeBookmark(for: url("/tmp/x"))
        }
    }

    // MARK: - Resolver double (fresh & stale)

    @Test("StubBookmarkResolver returns a fresh resolution and records input")
    func resolverDoubleFresh() throws {
        let expected = ResolvedBookmark(url: url("/tmp/Bookmarks.plist"), isStale: false)
        let resolver = StubBookmarkResolver(.success(expected))

        let resolved = try resolver.resolve(Data([0xAA]))

        #expect(resolved == expected)
        #expect(resolver.resolvedData == [Data([0xAA])])
    }

    @Test("StubBookmarkResolver can report a stale bookmark")
    func resolverDoubleStale() throws {
        let resolver = StubBookmarkResolver(
            .success(ResolvedBookmark(url: url("/tmp/Bookmarks.plist"), isStale: true))
        )
        let resolved = try resolver.resolve(Data([0xBB]))
        #expect(resolved.isStale)
    }

    @Test("StubBookmarkResolver propagates a configured error")
    func resolverDoubleFailure() {
        let resolver = StubBookmarkResolver(.failure(Boom()))
        #expect(throws: Boom.self) {
            _ = try resolver.resolve(Data([0x00]))
        }
    }

    // MARK: - Real resolver error path

    @Test("SystemSecurityScopedBookmarkResolver throws on invalid bookmark data")
    func systemResolverRejectsGarbage() {
        let resolver = SystemSecurityScopedBookmarkResolver()
        #expect(throws: (any Error).self) {
            _ = try resolver.resolve(Data([0x00, 0x01, 0x02, 0x03]))
        }
    }
}
