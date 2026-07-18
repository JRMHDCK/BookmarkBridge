//
//  BSEConflictResolverTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("BSE Conflict Resolver")
struct BSEConflictResolverTests {
    private let resolver = ConflictResolver()
    private let diffEngine = DiffEngine()

    private func logicalID(_ value: Int) throws -> LogicalNodeID {
        let string = String(format: "50000000-0000-0000-0000-%012d", value)
        return LogicalNodeID(try #require(UUID(uuidString: string)))
    }

    private func folder(
        _ value: Int,
        title: String = "Folder",
        parent: Int? = nil,
        position: Int = 0
    ) throws -> BSENode {
        try BSENode(
            logicalID: logicalID(value),
            kind: .folder,
            title: title,
            parentID: try parent.map(logicalID),
            position: position
        )
    }

    private func bookmark(
        _ value: Int,
        title: String = "Bookmark",
        parent: Int = 2,
        position: Int = 0,
        url: String = "https://example.com/"
    ) throws -> BSENode {
        try BSENode(
            logicalID: logicalID(value),
            kind: .bookmark,
            title: title,
            parentID: logicalID(parent),
            position: position,
            url: URL(string: url)
        )
    }

    private func snapshot(_ nodes: [BSENode], capturedAt: TimeInterval = 0) throws -> BSESnapshot {
        BSESnapshot(
            source: BSESourceID(try #require(UUID(uuidString: "60000000-0000-0000-0000-000000000001"))),
            capturedAt: Date(timeIntervalSince1970: capturedAt),
            tree: try BSETree(nodes: nodes)
        )
    }

    private func baseline(bookmarkCount: Int = 1) throws -> BSESnapshot {
        var nodes = [
            try folder(1, title: "Root"),
            try folder(2, title: "First", parent: 1),
            try folder(3, title: "Second", parent: 1),
        ]
        for offset in 0..<bookmarkCount {
            nodes.append(try bookmark(10 + offset, position: offset))
        }
        return try snapshot(nodes)
    }

    private func replacing(
        in baseline: BSESnapshot,
        with replacements: [BSENode],
        deleting deletedIDs: Set<LogicalNodeID> = []
    ) -> [BSENode] {
        let replacementsByID = Dictionary(
            uniqueKeysWithValues: replacements.map { ($0.logicalID, $0) }
        )
        return baseline.tree.nodes.compactMap { node in
            if deletedIDs.contains(node.logicalID) { return nil }
            return replacementsByID[node.logicalID] ?? node
        }
    }

    private func diff(from baseline: BSESnapshot, to nodes: [BSENode]) throws -> DiffResult {
        try diffEngine.diff(
            from: baseline,
            to: snapshot(nodes, capturedAt: 1)
        )
    }

    @Test("No changes produce no resolutions")
    func noChanges() throws {
        let baseline = try baseline()
        let empty = DiffResult(entries: [])

        let result = try resolver.resolve(baseline: baseline, left: empty, right: empty)

        #expect(result.isEmpty)
        #expect(result.resolutions == [])
    }

    @Test("A left-only change is applied from the left")
    func changeOnlyInLeft() throws {
        let baseline = try baseline()
        let left = try diff(
            from: baseline,
            to: replacing(in: baseline, with: [bookmark(10, title: "Left")])
        )

        let resolution = try #require(resolver.resolve(
            baseline: baseline,
            left: left,
            right: DiffResult(entries: [])
        ).resolutions.first)

        #expect(resolution.kind == .applyLeft)
        #expect(resolution.reason == .changedOnlyInLeft)
    }

    @Test("A right-only change is applied from the right")
    func changeOnlyInRight() throws {
        let baseline = try baseline()
        let right = try diff(
            from: baseline,
            to: replacing(in: baseline, with: [bookmark(10, title: "Right")])
        )

        let resolution = try #require(resolver.resolve(
            baseline: baseline,
            left: DiffResult(entries: []),
            right: right
        ).resolutions.first)

        #expect(resolution.kind == .applyRight)
        #expect(resolution.reason == .changedOnlyInRight)
    }

    @Test("The same rename requires no action")
    func identicalRename() throws {
        let baseline = try baseline()
        let renamed = replacing(in: baseline, with: [try bookmark(10, title: "Same")])
        let change = try diff(from: baseline, to: renamed)

        let resolution = try #require(resolver.resolve(
            baseline: baseline,
            left: change,
            right: change
        ).resolutions.first)

        #expect(resolution.kind == .noAction)
        #expect(resolution.reason == .identicalChanges)
    }

    @Test("Different concurrent renames conflict")
    func concurrentRenameConflict() throws {
        let baseline = try baseline()
        let left = try diff(
            from: baseline,
            to: replacing(in: baseline, with: [bookmark(10, title: "Left")])
        )
        let right = try diff(
            from: baseline,
            to: replacing(in: baseline, with: [bookmark(10, title: "Right")])
        )

        let resolution = try #require(resolver.resolve(
            baseline: baseline,
            left: left,
            right: right
        ).resolutions.first)

        #expect(resolution.kind == .conflict)
        #expect(resolution.reason == .concurrentRename)
    }

    @Test("The same move requires no action")
    func identicalMove() throws {
        let baseline = try baseline()
        let moved = replacing(in: baseline, with: [try bookmark(10, parent: 3, position: 2)])
        let change = try diff(from: baseline, to: moved)

        let resolution = try #require(resolver.resolve(
            baseline: baseline,
            left: change,
            right: change
        ).resolutions.first)

        #expect(resolution.kind == .noAction)
        #expect(resolution.reason == .identicalChanges)
    }

    @Test("Different concurrent moves conflict")
    func concurrentMoveConflict() throws {
        let baseline = try baseline()
        let left = try diff(
            from: baseline,
            to: replacing(in: baseline, with: [bookmark(10, parent: 3, position: 0)])
        )
        let right = try diff(
            from: baseline,
            to: replacing(in: baseline, with: [bookmark(10, parent: 2, position: 4)])
        )

        let resolution = try #require(resolver.resolve(
            baseline: baseline,
            left: left,
            right: right
        ).resolutions.first)

        #expect(resolution.kind == .conflict)
        #expect(resolution.reason == .concurrentMove)
    }

    @Test("Left rename and right move are compatible")
    func appliesLeftRenameAndRightMove() throws {
        let baseline = try baseline()
        let left = try diff(
            from: baseline,
            to: replacing(in: baseline, with: [bookmark(10, title: "Renamed")])
        )
        let right = try diff(
            from: baseline,
            to: replacing(in: baseline, with: [bookmark(10, parent: 3)])
        )

        let resolution = try #require(resolver.resolve(
            baseline: baseline,
            left: left,
            right: right
        ).resolutions.first)

        #expect(resolution.kind == .applyBoth)
        #expect(resolution.reason == .compatibleRenameAndMove)
        #expect(resolution.leftEvents.map(\.kind) == [.renameNode])
        #expect(resolution.rightEvents.map(\.kind) == [.moveNode])
    }

    @Test("Left move and right rename are compatible")
    func appliesLeftMoveAndRightRename() throws {
        let baseline = try baseline()
        let left = try diff(
            from: baseline,
            to: replacing(in: baseline, with: [bookmark(10, parent: 3)])
        )
        let right = try diff(
            from: baseline,
            to: replacing(in: baseline, with: [bookmark(10, title: "Renamed")])
        )

        let resolution = try #require(resolver.resolve(
            baseline: baseline,
            left: left,
            right: right
        ).resolutions.first)

        #expect(resolution.kind == .applyBoth)
        #expect(resolution.reason == .compatibleRenameAndMove)
        #expect(resolution.leftEvents.map(\.kind) == [.moveNode])
        #expect(resolution.rightEvents.map(\.kind) == [.renameNode])
    }

    @Test("Apply-both resolution is deterministic")
    func applyBothIsDeterministic() throws {
        let baseline = try baseline()
        let left = try diff(
            from: baseline,
            to: replacing(in: baseline, with: [bookmark(10, title: "Renamed")])
        )
        let right = try diff(
            from: baseline,
            to: replacing(in: baseline, with: [bookmark(10, parent: 3, position: 2)])
        )
        let expected = try resolver.resolve(baseline: baseline, left: left, right: right)

        for _ in 0..<10 {
            #expect(try resolver.resolve(
                baseline: baseline,
                left: left,
                right: right
            ) == expected)
        }
        #expect(expected.resolutions.first?.kind == .applyBoth)
    }

    @Test("Apply-both retains the original events from both sides")
    func applyBothPreservesBothSides() throws {
        let baseline = try baseline()
        let left = try diff(
            from: baseline,
            to: replacing(in: baseline, with: [bookmark(10, title: "Renamed")])
        )
        let right = try diff(
            from: baseline,
            to: replacing(in: baseline, with: [bookmark(10, parent: 3)])
        )

        let resolution = try #require(resolver.resolve(
            baseline: baseline,
            left: left,
            right: right
        ).resolutions.first)

        #expect(resolution.kind == .applyBoth)
        #expect(resolution.leftEntries == left.entries)
        #expect(resolution.rightEntries == right.entries)
        #expect(resolution.leftEvents == left.events)
        #expect(resolution.rightEvents == right.events)
    }

    @Test("Delete versus rename is a typed conflict")
    func deleteVersusRename() throws {
        let baseline = try baseline()
        let deletedID = try logicalID(10)
        let left = try diff(
            from: baseline,
            to: replacing(in: baseline, with: [], deleting: [deletedID])
        )
        let right = try diff(
            from: baseline,
            to: replacing(in: baseline, with: [bookmark(10, title: "Renamed")])
        )

        let resolution = try #require(resolver.resolve(
            baseline: baseline,
            left: left,
            right: right
        ).resolutions.first)

        #expect(resolution.kind == .conflict)
        #expect(resolution.reason == .deleteVsModify)
    }

    @Test("Delete versus move is a typed conflict")
    func deleteVersusMove() throws {
        let baseline = try baseline()
        let deletedID = try logicalID(10)
        let left = try diff(
            from: baseline,
            to: replacing(in: baseline, with: [], deleting: [deletedID])
        )
        let right = try diff(
            from: baseline,
            to: replacing(in: baseline, with: [bookmark(10, parent: 3)])
        )

        let resolution = try #require(resolver.resolve(
            baseline: baseline,
            left: left,
            right: right
        ).resolutions.first)

        #expect(resolution.kind == .conflict)
        #expect(resolution.reason == .deleteVsModify)
    }

    @Test("URL change versus rename is an URL conflict")
    func urlChangeVersusRename() throws {
        let baseline = try baseline()
        let left = try diff(
            from: baseline,
            to: replacing(in: baseline, with: [bookmark(10, url: "https://left.example/")])
        )
        let right = try diff(
            from: baseline,
            to: replacing(in: baseline, with: [bookmark(10, title: "Renamed")])
        )

        let resolution = try #require(resolver.resolve(
            baseline: baseline,
            left: left,
            right: right
        ).resolutions.first)

        #expect(resolution.kind == .conflict)
        #expect(resolution.reason == .urlConflict)
    }

    @Test("Identical URL changes require no action")
    func identicalURLChanges() throws {
        let baseline = try baseline()
        let changed = replacing(
            in: baseline,
            with: [try bookmark(10, url: "https://same.example/")]
        )
        let change = try diff(from: baseline, to: changed)

        let resolution = try #require(resolver.resolve(
            baseline: baseline,
            left: change,
            right: change
        ).resolutions.first)

        #expect(resolution.kind == .noAction)
        #expect(resolution.reason == .identicalChanges)
        #expect(resolution.leftEvents.map(\.kind) == [.createNode, .deleteNode])
    }

    @Test("Different URL changes conflict")
    func differentURLChanges() throws {
        let baseline = try baseline()
        let left = try diff(
            from: baseline,
            to: replacing(in: baseline, with: [bookmark(10, url: "https://left.example/")])
        )
        let right = try diff(
            from: baseline,
            to: replacing(in: baseline, with: [bookmark(10, url: "https://right.example/")])
        )

        let resolution = try #require(resolver.resolve(
            baseline: baseline,
            left: left,
            right: right
        ).resolutions.first)

        #expect(resolution.kind == .conflict)
        #expect(resolution.reason == .urlConflict)
    }

    @Test("Multiple conflicts remain independent")
    func multipleIndependentConflicts() throws {
        let baseline = try baseline(bookmarkCount: 2)
        let left = try diff(
            from: baseline,
            to: replacing(in: baseline, with: [
                bookmark(10, title: "Left 10", position: 0),
                bookmark(11, title: "Left 11", position: 1),
            ])
        )
        let right = try diff(
            from: baseline,
            to: replacing(in: baseline, with: [
                bookmark(10, title: "Right 10", position: 0),
                bookmark(11, title: "Right 11", position: 1),
            ])
        )

        let result = try resolver.resolve(baseline: baseline, left: left, right: right)

        #expect(result.resolutions.map(\.logicalID) == [try logicalID(10), try logicalID(11)])
        #expect(result.resolutions.allSatisfy { $0.kind == .conflict })
        #expect(result.resolutions.allSatisfy { $0.reason == .concurrentRename })
    }

    @Test("Multiple one-sided changes resolve automatically")
    func multipleAutomaticResolutions() throws {
        let baseline = try baseline(bookmarkCount: 2)
        let left = try diff(
            from: baseline,
            to: replacing(in: baseline, with: [bookmark(10, title: "Left", position: 0)])
        )
        let right = try diff(
            from: baseline,
            to: replacing(in: baseline, with: [bookmark(11, title: "Right", position: 1)])
        )

        let result = try resolver.resolve(baseline: baseline, left: left, right: right)

        #expect(result.resolutions.map(\.kind) == [.applyLeft, .applyRight])
        #expect(result.resolutions.map(\.reason) == [.changedOnlyInLeft, .changedOnlyInRight])
    }

    @Test("Resolution order is deterministic and independent of diff entry order")
    func deterministicOrder() throws {
        let baseline = try baseline(bookmarkCount: 2)
        let generatedLeft = try diff(
            from: baseline,
            to: replacing(in: baseline, with: [
                bookmark(10, title: "Left 10", position: 0),
                bookmark(11, parent: 3, position: 1),
            ])
        )
        let generatedRight = try diff(
            from: baseline,
            to: replacing(in: baseline, with: [
                bookmark(10, title: "Right 10", position: 0),
                bookmark(11, parent: 3, position: 2),
            ])
        )
        let reversedLeft = DiffResult(entries: Array(generatedLeft.entries.reversed()))
        let reversedRight = DiffResult(entries: Array(generatedRight.entries.reversed()))

        let forward = try resolver.resolve(
            baseline: baseline,
            left: generatedLeft,
            right: generatedRight
        )
        let reversed = try resolver.resolve(
            baseline: baseline,
            left: reversedLeft,
            right: reversedRight
        )

        #expect(forward == reversed)
        #expect(forward.resolutions.map(\.logicalID) == [try logicalID(10), try logicalID(11)])
        for _ in 0..<10 {
            #expect(try resolver.resolve(
                baseline: baseline,
                left: reversedLeft,
                right: reversedRight
            ) == forward)
        }
    }

    @Test("Original entries and events are retained")
    func preservesOriginalEvents() throws {
        let baseline = try baseline()
        let left = try diff(
            from: baseline,
            to: replacing(in: baseline, with: [bookmark(10, title: "Left")])
        )
        let right = try diff(
            from: baseline,
            to: replacing(in: baseline, with: [bookmark(10, title: "Right")])
        )

        let resolution = try #require(resolver.resolve(
            baseline: baseline,
            left: left,
            right: right
        ).resolutions.first)

        #expect(resolution.leftEntries == left.entries)
        #expect(resolution.rightEntries == right.entries)
        #expect(resolution.leftEvents == left.events)
        #expect(resolution.rightEvents == right.events)
    }

    @Test("Resolution leaves the baseline and diff values unchanged")
    func preservesInputImmutability() throws {
        let baseline = try baseline()
        let left = try diff(
            from: baseline,
            to: replacing(in: baseline, with: [bookmark(10, title: "Left")])
        )
        let right = try diff(
            from: baseline,
            to: replacing(in: baseline, with: [bookmark(10, title: "Right")])
        )
        let baselineCopy = baseline
        let leftCopy = left
        let rightCopy = right

        _ = try resolver.resolve(baseline: baseline, left: left, right: right)

        #expect(baseline == baselineCopy)
        #expect(left == leftCopy)
        #expect(right == rightCopy)
    }

    @Test("Duplicate event kinds are rejected explicitly")
    func rejectsDuplicateEvents() throws {
        let baseline = try baseline()
        let change = try diff(
            from: baseline,
            to: replacing(in: baseline, with: [bookmark(10, title: "Left")])
        )
        let entry = try #require(change.entries.first)
        let duplicated = DiffResult(entries: [entry, entry])

        #expect(throws: ConflictResolverError.duplicateEvent(
            logicalID: try logicalID(10),
            kind: .renameNode,
            side: .left
        )) {
            try resolver.resolve(
                baseline: baseline,
                left: duplicated,
                right: DiffResult(entries: [])
            )
        }
    }

    @Test("An event sequence inconsistent with the baseline is rejected")
    func rejectsInvalidSequence() throws {
        let baseline = try baseline()
        let node = try #require(baseline.tree.node(for: logicalID(10)))
        let event = try BSEEvent(
            kind: .createNode,
            logicalID: node.logicalID,
            before: nil,
            after: node
        )
        let invalid = DiffResult(entries: [
            DiffEntry(event: event, reason: .createdInAfterSnapshot),
        ])

        #expect(throws: ConflictResolverError.invalidEventSequence(
            logicalID: node.logicalID,
            side: .right
        )) {
            try resolver.resolve(
                baseline: baseline,
                left: DiffResult(entries: []),
                right: invalid
            )
        }
    }
}
