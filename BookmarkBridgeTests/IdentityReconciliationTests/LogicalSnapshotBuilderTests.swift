//
//  LogicalSnapshotBuilderTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("BSE Logical Snapshot Builder")
struct LogicalSnapshotBuilderTests {
    private let builder = LogicalSnapshotBuilder()

    @Test("Rekeys nodes and parent references with supplied durable IDs")
    func rekeysTree() throws {
        let sourceID = try ReconciliationTestSupport.sourceID(1)
        let provisionalRoot = try ReconciliationTestSupport.provisionalID(1)
        let provisionalBookmark = try ReconciliationTestSupport.provisionalID(2)
        let durableRoot = try ReconciliationTestSupport.durableID(1)
        let durableBookmark = try ReconciliationTestSupport.durableID(2)
        let snapshot = try ReconciliationTestSupport.snapshot(
            source: sourceID,
            nodes: [
                ReconciliationTestSupport.folder(id: provisionalRoot, title: "Root"),
                ReconciliationTestSupport.bookmark(
                    id: provisionalBookmark,
                    parentID: provisionalRoot,
                    title: "Café 📚"
                ),
            ]
        )

        let logical = try builder.build(
            from: snapshot,
            assignments: [
                assignment(sourceID, provisionalRoot, durableRoot),
                assignment(sourceID, provisionalBookmark, durableBookmark),
            ]
        )

        let root = try #require(logical.tree.node(for: durableRoot))
        let bookmark = try #require(logical.tree.node(for: durableBookmark))
        #expect(root.title == "Root")
        #expect(bookmark.title == "Café 📚")
        #expect(bookmark.parentID == durableRoot)
        #expect(bookmark.url?.absoluteString == "https://example.com")
        #expect(logical.source == snapshot.source)
        #expect(logical.capturedAt == snapshot.capturedAt)
    }

    @Test("Builder never mutates the provisional snapshot")
    func preservesInput() throws {
        let sourceID = try ReconciliationTestSupport.sourceID(1)
        let provisionalID = try ReconciliationTestSupport.provisionalID(1)
        let snapshot = try ReconciliationTestSupport.snapshot(
            source: sourceID,
            nodes: [ReconciliationTestSupport.folder(id: provisionalID)]
        )
        let before = snapshot

        _ = try builder.build(
            from: snapshot,
            assignments: [assignment(
                sourceID,
                provisionalID,
                ReconciliationTestSupport.durableID(1)
            )]
        )

        #expect(snapshot == before)
    }

    @Test("Incomplete assignments are rejected explicitly")
    func incompleteAssignments() throws {
        let sourceID = try ReconciliationTestSupport.sourceID(1)
        let provisionalID = try ReconciliationTestSupport.provisionalID(1)
        let snapshot = try ReconciliationTestSupport.snapshot(
            source: sourceID,
            nodes: [ReconciliationTestSupport.folder(id: provisionalID)]
        )

        #expect(throws: IdentityReconciliationError.incompleteAssignments(sourceID)) {
            _ = try builder.build(from: snapshot, assignments: [])
        }
    }

    @Test("Two objects in one source cannot share a durable identity")
    func duplicateDurableIdentity() throws {
        let sourceID = try ReconciliationTestSupport.sourceID(1)
        let provisionalRoot = try ReconciliationTestSupport.provisionalID(1)
        let provisionalChild = try ReconciliationTestSupport.provisionalID(2)
        let durableID = try ReconciliationTestSupport.durableID(1)
        let snapshot = try ReconciliationTestSupport.snapshot(
            source: sourceID,
            nodes: [
                ReconciliationTestSupport.folder(id: provisionalRoot),
                ReconciliationTestSupport.folder(
                    id: provisionalChild,
                    parentID: provisionalRoot
                ),
            ]
        )

        #expect(throws: IdentityReconciliationError.duplicateLogicalIdentity(sourceID)) {
            _ = try builder.build(
                from: snapshot,
                assignments: [
                    assignment(sourceID, provisionalRoot, durableID),
                    assignment(sourceID, provisionalChild, durableID),
                ]
            )
        }
    }

    @Test("LogicalSnapshot is Codable and value-stable")
    func codable() throws {
        let sourceID = try ReconciliationTestSupport.sourceID(1)
        let provisionalID = try ReconciliationTestSupport.provisionalID(1)
        let snapshot = try ReconciliationTestSupport.snapshot(
            source: sourceID,
            nodes: [ReconciliationTestSupport.folder(id: provisionalID)]
        )
        let logical = try builder.build(
            from: snapshot,
            assignments: [assignment(
                sourceID,
                provisionalID,
                ReconciliationTestSupport.durableID(1)
            )]
        )

        let data = try JSONEncoder().encode(logical)

        #expect(try JSONDecoder().decode(LogicalSnapshot.self, from: data) == logical)
    }

    private func assignment(
        _ sourceID: BSESourceID,
        _ provisionalID: LogicalNodeID,
        _ durableID: LogicalNodeID
    ) -> LogicalIdentityAssignment {
        LogicalIdentityAssignment(
            sourceID: sourceID,
            provisionalLogicalID: provisionalID,
            logicalNodeID: durableID
        )
    }
}
