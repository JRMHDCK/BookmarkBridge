//
//  LogicalDiffEngineTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("BSE Logical Diff v2")
struct LogicalDiffEngineTests {
    @Test("Identical graphs produce no change")
    func noChange() throws {
        let node = try LogicalDiffTestSupport.folder(id: 1)
        let graph = try LogicalDiffTestSupport.graph([node])

        let result = try LogicalDiffEngine().diff(
            request: LogicalDiffRequest(before: graph, after: graph)
        )

        #expect(result.changes.isEmpty)
        #expect(result.report.unchangedNodeCount == 1)
        #expect(result.report.changeCount == 0)
    }

    @Test("A node present only after is created")
    func creation() throws {
        let node = try LogicalDiffTestSupport.folder(id: 1)
        let result = try LogicalDiffTestSupport.diff(before: [], after: [node])

        #expect(result.changes == [.created(CreatedChange(after: node))])
        #expect(result.report.createdCount == 1)
    }

    @Test("A node present only before is deleted")
    func deletion() throws {
        let node = try LogicalDiffTestSupport.folder(id: 1)
        let result = try LogicalDiffTestSupport.diff(before: [node], after: [])

        #expect(result.changes == [.deleted(DeletedChange(before: node))])
        #expect(result.report.deletedCount == 1)
    }

    @Test("A title change is represented as a rename")
    func rename() throws {
        let before = try LogicalDiffTestSupport.folder(id: 1, title: "Before")
        let after = try LogicalDiffTestSupport.folder(id: 1, title: "After")

        let result = try LogicalDiffTestSupport.diff(before: [before], after: [after])

        #expect(result.changes == [.renamed(RenamedChange(
            logicalNodeID: before.logicalNodeID,
            before: "Before",
            after: "After"
        ))])
    }

    @Test("A bookmark URL change is explicit")
    func urlChanged() throws {
        let root = try LogicalDiffTestSupport.folder(id: 1)
        let before = try LogicalDiffTestSupport.bookmark(id: 2, parent: 1, url: "https://before.test")
        let after = try LogicalDiffTestSupport.bookmark(id: 2, parent: 1, url: "https://after.test")

        let result = try LogicalDiffTestSupport.diff(
            before: [root, before],
            after: [root, after]
        )

        #expect(result.changes == [.urlChanged(URLChangedChange(
            logicalNodeID: before.logicalNodeID,
            before: before.url,
            after: after.url
        ))])
    }

    @Test("A parent change is represented as a move")
    func moved() throws {
        let firstParent = try LogicalDiffTestSupport.folder(id: 1)
        let secondParent = try LogicalDiffTestSupport.folder(id: 2)
        let before = try LogicalDiffTestSupport.bookmark(id: 3, parent: 1)
        let after = try LogicalDiffTestSupport.bookmark(id: 3, parent: 2)

        let result = try LogicalDiffTestSupport.diff(
            before: [firstParent, secondParent, before],
            after: [firstParent, secondParent, after]
        )

        #expect(result.changes == [.moved(MovedChange(
            logicalNodeID: before.logicalNodeID,
            before: firstParent.logicalNodeID,
            after: secondParent.logicalNodeID
        ))])
    }

    @Test("A position change is represented as a reorder")
    func reordered() throws {
        let before = try LogicalDiffTestSupport.folder(id: 1, position: 0)
        let after = try LogicalDiffTestSupport.folder(id: 1, position: 4)

        let result = try LogicalDiffTestSupport.diff(before: [before], after: [after])

        #expect(result.changes == [.reordered(ReorderedChange(
            logicalNodeID: before.logicalNodeID,
            before: 0,
            after: 4
        ))])
    }

    @Test("A lifecycle transition is represented explicitly")
    func lifecycleChanged() throws {
        let before = try LogicalDiffTestSupport.folder(
            id: 1,
            lifecycle: .registered(.active)
        )
        let after = try LogicalDiffTestSupport.folder(
            id: 1,
            lifecycle: .registered(.archived)
        )

        let result = try LogicalDiffTestSupport.diff(before: [before], after: [after])

        #expect(result.changes == [.lifecycleChanged(LifecycleChangedChange(
            logicalNodeID: before.logicalNodeID,
            before: .registered(.active),
            after: .registered(.archived)
        ))])
    }

    @Test("One node can produce independent rename and move changes")
    func multipleChangesForOneNode() throws {
        let firstParent = try LogicalDiffTestSupport.folder(id: 1)
        let secondParent = try LogicalDiffTestSupport.folder(id: 2)
        let before = try LogicalDiffTestSupport.bookmark(
            id: 3,
            parent: 1,
            title: "Before"
        )
        let after = try LogicalDiffTestSupport.bookmark(
            id: 3,
            parent: 2,
            title: "After"
        )

        let result = try LogicalDiffTestSupport.diff(
            before: [firstParent, secondParent, before],
            after: [firstParent, secondParent, after]
        )

        #expect(result.changes == [
            .renamed(RenamedChange(
                logicalNodeID: before.logicalNodeID,
                before: "Before",
                after: "After"
            )),
            .moved(MovedChange(
                logicalNodeID: before.logicalNodeID,
                before: firstParent.logicalNodeID,
                after: secondParent.logicalNodeID
            )),
        ])
    }

    @Test("Multiple nodes are ordered by identity then change kind")
    func multipleNodes() throws {
        let deleted = try LogicalDiffTestSupport.folder(id: 3)
        let renamedBefore = try LogicalDiffTestSupport.folder(id: 2, title: "Before")
        let renamedAfter = try LogicalDiffTestSupport.folder(id: 2, title: "After")
        let created = try LogicalDiffTestSupport.folder(id: 1)

        let result = try LogicalDiffTestSupport.diff(
            before: [deleted, renamedBefore],
            after: [renamedAfter, created]
        )

        #expect(result.changes.map(\.logicalNodeID) == [
            created.logicalNodeID,
            renamedBefore.logicalNodeID,
            deleted.logicalNodeID,
        ])
        #expect(result.report.createdCount == 1)
        #expect(result.report.renamedCount == 1)
        #expect(result.report.deletedCount == 1)
    }

    @Test("Input node order cannot affect the result")
    func deterministic() throws {
        let beforeNodes = try [
            LogicalDiffTestSupport.folder(id: 2, title: "Before"),
            LogicalDiffTestSupport.folder(id: 1),
        ]
        let afterNodes = try [
            LogicalDiffTestSupport.folder(id: 1),
            LogicalDiffTestSupport.folder(id: 2, title: "After"),
        ]
        let engine = LogicalDiffEngine()
        let first = try engine.diff(request: LogicalDiffRequest(
            before: LogicalDiffTestSupport.graph(beforeNodes),
            after: LogicalDiffTestSupport.graph(afterNodes)
        ))
        let second = try engine.diff(request: LogicalDiffRequest(
            before: LogicalDiffTestSupport.graph(Array(beforeNodes.reversed())),
            after: LogicalDiffTestSupport.graph(Array(afterNodes.reversed()))
        ))

        #expect(first == second)
    }

    @Test("Diffing does not mutate immutable graph inputs")
    func inputsRemainUnchanged() throws {
        let before = try LogicalDiffTestSupport.graph([
            LogicalDiffTestSupport.folder(id: 1, title: "Before"),
        ])
        let after = try LogicalDiffTestSupport.graph([
            LogicalDiffTestSupport.folder(id: 1, title: "After"),
        ])
        let originalBefore = before
        let originalAfter = after

        _ = try LogicalDiffEngine().diff(
            request: LogicalDiffRequest(before: before, after: after)
        )

        #expect(before == originalBefore)
        #expect(after == originalAfter)
    }

    @Test("A node kind mismatch is rejected instead of being corrected")
    func inconsistentState() throws {
        let parent = try LogicalDiffTestSupport.folder(id: 1)
        let before = try LogicalDiffTestSupport.bookmark(id: 2, parent: 1)
        let after = try LogicalDiffTestSupport.folder(id: 2)

        #expect(throws: LogicalDiffError.inconsistentState(before.logicalNodeID)) {
            _ = try LogicalDiffTestSupport.diff(
                before: [parent, before],
                after: [parent, after]
            )
        }
    }

    @Test("Models and engine satisfy Swift Concurrency boundaries")
    func strictConcurrency() throws {
        let graph = try LogicalDiffTestSupport.graph([])
        let request = LogicalDiffRequest(before: graph, after: graph)
        let result = try LogicalDiffEngine().diff(request: request)

        requireSendable(LogicalDiffEngine())
        requireSendable(request)
        requireSendable(result)
        requireSendable(result.changes)
    }

    private func requireSendable<T: Sendable>(_ value: T) { _ = value }
}

private enum LogicalDiffTestSupport {
    static let emptyReport = LogicalStateBuildingReport(
        baselineIdentityCount: 0,
        snapshotCount: 0,
        snapshotNodeCount: 0,
        logicalNodeCount: 0,
        structurallyAvailableNodeCount: 0,
        baselineOnlyNodeCount: 0,
        unregisteredNodeCount: 0,
        observationCount: 0
    )

    static func diff(
        before: [LogicalNodeState],
        after: [LogicalNodeState]
    ) throws -> LogicalDiffResult {
        try LogicalDiffEngine().diff(request: LogicalDiffRequest(
            before: graph(before),
            after: graph(after)
        ))
    }

    static func graph(_ nodes: [LogicalNodeState]) throws -> LogicalStateGraph {
        try LogicalStateGraph(nodes: nodes, report: emptyReport)
    }

    static func folder(
        id: Int,
        title: String = "Folder",
        position: Int = 0,
        lifecycle: LogicalNodeLifecycle = .unregistered
    ) throws -> LogicalNodeState {
        try LogicalNodeState(
            logicalNodeID: logicalID(id),
            kind: .folder,
            title: title,
            url: nil,
            parentID: nil,
            position: position,
            lifecycle: lifecycle,
            observations: []
        )
    }

    static func bookmark(
        id: Int,
        parent: Int,
        title: String = "Bookmark",
        url: String = "https://example.test",
        position: Int = 0,
        lifecycle: LogicalNodeLifecycle = .unregistered
    ) throws -> LogicalNodeState {
        try LogicalNodeState(
            logicalNodeID: logicalID(id),
            kind: .bookmark,
            title: title,
            url: URL(string: url),
            parentID: logicalID(parent),
            position: position,
            lifecycle: lifecycle,
            observations: []
        )
    }

    static func logicalID(_ value: Int) -> LogicalNodeID {
        LogicalNodeID(UUID(uuidString: String(
            format: "00000000-0000-0000-0000-%012d",
            value
        ))!)
    }
}
