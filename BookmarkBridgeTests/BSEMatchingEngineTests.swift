//
//  BSEMatchingEngineTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("BSE Matching Engine")
struct BSEMatchingEngineTests {
    private let engine = MatchingEngine()

    private func logicalID(_ value: Int) throws -> LogicalNodeID {
        let string = String(format: "20000000-0000-0000-0000-%012d", value)
        return LogicalNodeID(try #require(UUID(uuidString: string)))
    }

    private func folder(
        _ id: LogicalNodeID,
        title: String = "Folder",
        permanentRootRole: PermanentRootRole? = nil
    ) throws -> BSENode {
        try BSENode(
            logicalID: id,
            kind: .folder,
            permanentRootRole: permanentRootRole,
            title: title,
            position: 0
        )
    }

    private func bookmark(
        _ id: LogicalNodeID,
        url: String,
        title: String = "Bookmark"
    ) throws -> BSENode {
        try BSENode(
            logicalID: id,
            kind: .bookmark,
            title: title,
            position: 0,
            url: URL(string: url)
        )
    }

    @Test("Matches nodes with the same LogicalNodeID")
    func matchesSameLogicalIdentifier() throws {
        let id = try logicalID(1)
        let result = engine.match(
            try folder(id, title: "Before"),
            with: try folder(id, title: "After")
        )

        #expect(result == .match(candidateID: id, reason: .sameLogicalID))
        #expect(result.reason == .sameLogicalID)
    }

    @Test("Matches bookmarks with identical URLs and different identifiers")
    func matchesSameBookmarkURL() throws {
        let candidateID = try logicalID(2)
        let result = engine.match(
            try bookmark(logicalID(1), url: "https://example.com/path"),
            with: try bookmark(candidateID, url: "https://example.com/path")
        )

        #expect(result == .match(candidateID: candidateID, reason: .sameBookmarkURL))
        #expect(result.reason == .sameBookmarkURL)
    }

    @Test("Does not match bookmarks with different URLs")
    func rejectsDifferentBookmarkURLs() throws {
        let result = engine.match(
            try bookmark(logicalID(1), url: "https://example.com/one"),
            with: try bookmark(logicalID(2), url: "https://example.com/two")
        )

        #expect(result == .noMatch(reason: .differentBookmarkURL))
    }

    @Test("Does not match a folder with a bookmark")
    func rejectsDifferentNodeKinds() throws {
        let id = try logicalID(1)
        let result = engine.match(
            try folder(id),
            with: try bookmark(id, url: "https://example.com/")
        )

        #expect(result == .noMatch(reason: .differentNodeKind))
        #expect(result.reason == .differentNodeKind)
    }

    @Test("Folders with different identifiers do not match")
    func rejectsFoldersWithDifferentIdentifiers() throws {
        let result = engine.match(
            try folder(logicalID(1)),
            with: try folder(logicalID(2))
        )

        #expect(result == .noMatch(reason: .differentLogicalID))
    }

    @Test("Permanent roots match only through an equal declared role")
    func matchesPermanentRootRole() throws {
        let candidateID = try logicalID(2)
        let result = engine.match(
            try folder(
                logicalID(1),
                title: "Source native title",
                permanentRootRole: .primaryBookmarks
            ),
            with: try folder(
                candidateID,
                title: "Target native title",
                permanentRootRole: .primaryBookmarks
            )
        )

        #expect(result == .match(
            candidateID: candidateID,
            reason: .samePermanentRootRole
        ))
    }

    @Test("Distinct or missing permanent-root roles never match")
    func rejectsNonHomologousPermanentRoots() throws {
        let primary = try folder(
            logicalID(1),
            permanentRootRole: .primaryBookmarks
        )

        #expect(engine.match(
            primary,
            with: try folder(
                logicalID(2),
                permanentRootRole: .mobileBookmarks
            )
        ) == .noMatch(reason: .differentPermanentRootRole))
        #expect(engine.match(
            primary,
            with: try folder(logicalID(3))
        ) == .noMatch(reason: .differentPermanentRootRole))
    }

    @Test("Reports every valid candidate as ambiguous")
    func reportsMultipleCandidatesAsAmbiguous() throws {
        let firstID = try logicalID(2)
        let secondID = try logicalID(3)
        let node = try bookmark(logicalID(1), url: "https://example.com/")
        let candidates = [
            try bookmark(secondID, url: "https://example.com/"),
            try bookmark(firstID, url: "https://example.com/"),
        ]

        let result = engine.match(node, among: candidates)

        #expect(result == .ambiguous(
            candidateIDs: [firstID, secondID],
            reason: .ambiguousCandidates(count: 2)
        ))
        #expect(result.reason == .ambiguousCandidates(count: 2))
    }

    @Test("An empty candidate collection yields no match")
    func reportsNoCandidates() throws {
        let result = engine.match(try folder(logicalID(1)), among: [])

        #expect(result == .noMatch(reason: .noCandidates))
        #expect(result.reason == .noCandidates)
    }

    @Test("Multiple invalid candidates yield no matching candidate")
    func reportsNoMatchingCandidate() throws {
        let node = try bookmark(logicalID(1), url: "https://example.com/source")
        let candidates = [
            try bookmark(logicalID(2), url: "https://example.com/other"),
            try folder(logicalID(3)),
        ]

        #expect(engine.match(node, among: candidates) == .noMatch(reason: .noMatchingCandidate))
    }

    @Test("A single valid candidate is returned with its explanation")
    func returnsSingleCandidate() throws {
        let candidateID = try logicalID(2)
        let node = try bookmark(logicalID(1), url: "https://example.com/")
        let candidates = [
            try bookmark(logicalID(3), url: "https://other.example/"),
            try bookmark(candidateID, url: "https://example.com/"),
        ]

        let result = engine.match(node, among: candidates)

        #expect(result == .match(candidateID: candidateID, reason: .sameBookmarkURL))
    }

    @Test("Candidate order never changes an ambiguous result")
    func resultIsDeterministic() throws {
        let node = try bookmark(logicalID(1), url: "https://example.com/")
        let candidates = [
            try bookmark(logicalID(2), url: "https://example.com/"),
            try bookmark(logicalID(3), url: "https://example.com/"),
            try bookmark(logicalID(4), url: "https://other.example/"),
        ]

        let forward = engine.match(node, among: candidates)
        let reversed = engine.match(node, among: Array(candidates.reversed()))

        #expect(forward == reversed)
    }
}
