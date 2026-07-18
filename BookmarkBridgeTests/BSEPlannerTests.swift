//
//  BSEPlannerTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("BSE Planner")
struct BSEPlannerTests {
    private let planner = Planner()

    private func logicalID(_ value: Int) throws -> LogicalNodeID {
        let string = String(format: "70000000-0000-0000-0000-%012d", value)
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
        parent: Int = 1,
        position: Int = 0
    ) throws -> BSENode {
        try BSENode(
            logicalID: logicalID(value),
            kind: .bookmark,
            title: title,
            parentID: logicalID(parent),
            position: position,
            url: URL(string: "https://example.com/\(value)")
        )
    }

    private func entry(
        kind: BSEEventKind,
        before: BSENode?,
        after: BSENode?,
        reason: DiffReason
    ) throws -> DiffEntry {
        let logicalID = try #require(before?.logicalID ?? after?.logicalID)
        return DiffEntry(
            event: try BSEEvent(
                kind: kind,
                logicalID: logicalID,
                before: before,
                after: after
            ),
            reason: reason
        )
    }

    private func resolution(
        kind: ConflictResolutionKind,
        logicalID: LogicalNodeID,
        left: [DiffEntry] = [],
        right: [DiffEntry] = [],
        reason: ConflictReason = .changedOnlyInLeft
    ) -> ConflictResolution {
        ConflictResolution(
            logicalID: logicalID,
            kind: kind,
            reason: reason,
            leftEntries: left,
            rightEntries: right
        )
    }

    private func renameEntry(_ value: Int, title: String = "Renamed") throws -> DiffEntry {
        try entry(
            kind: .renameNode,
            before: bookmark(value, title: "Before"),
            after: bookmark(value, title: title),
            reason: .titleChanged
        )
    }

    private func moveEntry(
        _ value: Int,
        from oldParent: Int = 1,
        to newParent: Int = 2,
        position: Int = 0
    ) throws -> DiffEntry {
        try entry(
            kind: .moveNode,
            before: bookmark(value, parent: oldParent),
            after: bookmark(value, parent: newParent, position: position),
            reason: .parentChanged
        )
    }

    @Test("An empty conflict result produces an empty plan")
    func emptyPlan() throws {
        let plan = try planner.plan(from: ConflictResult(resolutions: []))

        #expect(plan.isEmpty)
        #expect(plan.steps == [])
        #expect(plan.unplannedResolutions == [])
    }

    @Test("Apply-left create produces one create step")
    func applyLeftCreate() throws {
        let node = try bookmark(10)
        let diffEntry = try entry(
            kind: .createNode,
            before: nil,
            after: node,
            reason: .createdInAfterSnapshot
        )
        let source = resolution(
            kind: .applyLeft,
            logicalID: node.logicalID,
            left: [diffEntry]
        )

        let step = try #require(planner.plan(
            from: ConflictResult(resolutions: [source])
        ).steps.first)

        #expect(step.kind == .create)
        #expect(step.event == diffEntry.event)
    }

    @Test("Apply-right delete produces one delete step")
    func applyRightDelete() throws {
        let node = try bookmark(10)
        let diffEntry = try entry(
            kind: .deleteNode,
            before: node,
            after: nil,
            reason: .missingFromAfterSnapshot
        )
        let source = resolution(
            kind: .applyRight,
            logicalID: node.logicalID,
            right: [diffEntry],
            reason: .changedOnlyInRight
        )

        let step = try #require(planner.plan(
            from: ConflictResult(resolutions: [source])
        ).steps.first)

        #expect(step.kind == .delete)
        #expect(step.resolution == source)
    }

    @Test("Apply-left rename produces one rename step")
    func applyLeftRename() throws {
        let diffEntry = try renameEntry(10)
        let source = resolution(
            kind: .applyLeft,
            logicalID: diffEntry.event.logicalID,
            left: [diffEntry]
        )

        let plan = try planner.plan(from: ConflictResult(resolutions: [source]))

        #expect(plan.steps.map(\.kind) == [.rename])
    }

    @Test("Apply-left move produces one move step")
    func applyLeftMove() throws {
        let diffEntry = try moveEntry(10)
        let source = resolution(
            kind: .applyLeft,
            logicalID: diffEntry.event.logicalID,
            left: [diffEntry]
        )

        let plan = try planner.plan(from: ConflictResult(resolutions: [source]))

        #expect(plan.steps.map(\.kind) == [.move])
    }

    @Test("Apply-both rename and move produces move then rename")
    func applyBothRenameAndMove() throws {
        let rename = try renameEntry(10)
        let move = try moveEntry(10)
        let source = resolution(
            kind: .applyBoth,
            logicalID: rename.event.logicalID,
            left: [rename],
            right: [move],
            reason: .compatibleRenameAndMove
        )

        let plan = try planner.plan(from: ConflictResult(resolutions: [source]))

        #expect(plan.steps.map(\.kind) == [.move, .rename])
        #expect(plan.steps.allSatisfy { $0.resolution == source })
    }

    @Test("No-action produces no step")
    func noActionProducesNoStep() throws {
        let diffEntry = try renameEntry(10)
        let source = resolution(
            kind: .noAction,
            logicalID: diffEntry.event.logicalID,
            left: [diffEntry],
            right: [diffEntry],
            reason: .identicalChanges
        )

        let plan = try planner.plan(from: ConflictResult(resolutions: [source]))

        #expect(plan.isEmpty)
        #expect(plan.steps == [])
        #expect(plan.unplannedResolutions == [])
    }

    @Test("Conflict produces no step and remains unplanned")
    func conflictRemainsUnplanned() throws {
        let left = try renameEntry(10, title: "Left")
        let right = try renameEntry(10, title: "Right")
        let source = resolution(
            kind: .conflict,
            logicalID: left.event.logicalID,
            left: [left],
            right: [right],
            reason: .concurrentRename
        )

        let plan = try planner.plan(from: ConflictResult(resolutions: [source]))

        #expect(plan.steps == [])
        #expect(plan.unplannedResolutions == [source])
        #expect(!plan.isEmpty)
    }

    @Test("Created parents and folders precede their bookmarks")
    func createsFoldersBeforeBookmarks() throws {
        let parent = try folder(20)
        let child = try bookmark(10, parent: 20)
        let parentEntry = try entry(
            kind: .createNode,
            before: nil,
            after: parent,
            reason: .createdInAfterSnapshot
        )
        let childEntry = try entry(
            kind: .createNode,
            before: nil,
            after: child,
            reason: .createdInAfterSnapshot
        )
        let resolutions = [
            resolution(kind: .applyLeft, logicalID: child.logicalID, left: [childEntry]),
            resolution(kind: .applyLeft, logicalID: parent.logicalID, left: [parentEntry]),
        ]

        let plan = try planner.plan(from: ConflictResult(resolutions: resolutions))

        #expect(plan.steps.map(\.logicalID) == [parent.logicalID, child.logicalID])
        #expect(plan.steps.map(\.kind) == [.create, .create])
    }

    @Test("Deleted children and bookmarks precede their folders")
    func deletesBookmarksBeforeFolders() throws {
        let parent = try folder(10)
        let child = try bookmark(20, parent: 10)
        let parentEntry = try entry(
            kind: .deleteNode,
            before: parent,
            after: nil,
            reason: .missingFromAfterSnapshot
        )
        let childEntry = try entry(
            kind: .deleteNode,
            before: child,
            after: nil,
            reason: .missingFromAfterSnapshot
        )
        let resolutions = [
            resolution(kind: .applyLeft, logicalID: parent.logicalID, left: [parentEntry]),
            resolution(kind: .applyLeft, logicalID: child.logicalID, left: [childEntry]),
        ]

        let plan = try planner.plan(from: ConflictResult(resolutions: resolutions))

        #expect(plan.steps.map(\.logicalID) == [child.logicalID, parent.logicalID])
        #expect(plan.steps.map(\.kind) == [.delete, .delete])
    }

    @Test("Moved parents precede moved children")
    func ordersMoveDependencies() throws {
        let parentBefore = try folder(20, parent: 1)
        let parentAfter = try folder(20, parent: 2)
        let childBefore = try bookmark(10, parent: 1)
        let childAfter = try bookmark(10, parent: 20)
        let parentMove = try entry(
            kind: .moveNode,
            before: parentBefore,
            after: parentAfter,
            reason: .parentChanged
        )
        let childMove = try entry(
            kind: .moveNode,
            before: childBefore,
            after: childAfter,
            reason: .parentChanged
        )
        let resolutions = [
            resolution(kind: .applyLeft, logicalID: childAfter.logicalID, left: [childMove]),
            resolution(kind: .applyLeft, logicalID: parentAfter.logicalID, left: [parentMove]),
        ]

        let plan = try planner.plan(from: ConflictResult(resolutions: resolutions))

        #expect(plan.steps.map(\.logicalID) == [parentAfter.logicalID, childAfter.logicalID])
    }

    @Test("Step categories and identifiers have a deterministic order")
    func deterministicCategoryOrder() throws {
        let createNode = try bookmark(40)
        let deleteNode = try bookmark(30)
        let create = try entry(
            kind: .createNode,
            before: nil,
            after: createNode,
            reason: .createdInAfterSnapshot
        )
        let delete = try entry(
            kind: .deleteNode,
            before: deleteNode,
            after: nil,
            reason: .missingFromAfterSnapshot
        )
        let move = try moveEntry(20)
        let rename = try renameEntry(10)
        let resolutions = [
            resolution(kind: .applyLeft, logicalID: rename.event.logicalID, left: [rename]),
            resolution(kind: .applyLeft, logicalID: move.event.logicalID, left: [move]),
            resolution(kind: .applyLeft, logicalID: delete.event.logicalID, left: [delete]),
            resolution(kind: .applyLeft, logicalID: create.event.logicalID, left: [create]),
        ]

        let plan = try planner.plan(from: ConflictResult(resolutions: resolutions))

        #expect(plan.steps.map(\.kind) == [.create, .delete, .move, .rename])
    }

    @Test("Strictly identical events are deduplicated")
    func removesDuplicates() throws {
        let diffEntry = try renameEntry(10)
        let first = resolution(
            kind: .applyLeft,
            logicalID: diffEntry.event.logicalID,
            left: [diffEntry]
        )
        let second = resolution(
            kind: .applyRight,
            logicalID: diffEntry.event.logicalID,
            right: [diffEntry],
            reason: .changedOnlyInRight
        )

        let plan = try planner.plan(from: ConflictResult(resolutions: [second, first]))

        #expect(plan.steps.count == 1)
        #expect(plan.steps.first?.event == diffEntry.event)
    }

    @Test("Every step retains its resolution, entry, and event")
    func preservesTraceability() throws {
        let diffEntry = try renameEntry(10)
        let source = resolution(
            kind: .applyLeft,
            logicalID: diffEntry.event.logicalID,
            left: [diffEntry]
        )

        let step = try #require(planner.plan(
            from: ConflictResult(resolutions: [source])
        ).steps.first)

        #expect(step.resolution == source)
        #expect(step.entry == diffEntry)
        #expect(step.event == diffEntry.event)
        #expect(step.resolution.leftEntries.first == step.entry)
    }

    @Test("Planning is deterministic across repeated executions")
    func planningIsDeterministic() throws {
        let firstEntry = try renameEntry(10)
        let secondEntry = try moveEntry(20)
        let input = ConflictResult(resolutions: [
            resolution(kind: .applyLeft, logicalID: secondEntry.event.logicalID, left: [secondEntry]),
            resolution(kind: .applyLeft, logicalID: firstEntry.event.logicalID, left: [firstEntry]),
        ])
        let expected = try planner.plan(from: input)

        for _ in 0..<10 {
            #expect(try planner.plan(from: input) == expected)
        }
    }

    @Test("Planning leaves conflict models unchanged")
    func preservesModelImmutability() throws {
        let diffEntry = try renameEntry(10)
        let source = resolution(
            kind: .applyLeft,
            logicalID: diffEntry.event.logicalID,
            left: [diffEntry]
        )
        let input = ConflictResult(resolutions: [source])
        let inputCopy = input
        let sourceCopy = source

        _ = try planner.plan(from: input)

        #expect(input == inputCopy)
        #expect(source == sourceCopy)
    }

    @Test("Contradictory selected operations are rejected")
    func rejectsContradictoryOperations() throws {
        let firstEntry = try renameEntry(10, title: "First")
        let secondEntry = try renameEntry(10, title: "Second")
        let input = ConflictResult(resolutions: [
            resolution(kind: .applyLeft, logicalID: firstEntry.event.logicalID, left: [firstEntry]),
            resolution(kind: .applyRight, logicalID: secondEntry.event.logicalID, right: [secondEntry]),
        ])

        #expect(throws: PlannerError.contradictoryEvents(
            logicalID: try logicalID(10),
            kind: .rename
        )) {
            try planner.plan(from: input)
        }
    }

    @Test("A selected side without entries is rejected")
    func rejectsMissingSelectedEntries() throws {
        let source = resolution(
            kind: .applyLeft,
            logicalID: try logicalID(10),
            left: []
        )

        #expect(throws: PlannerError.missingSelectedEntries(
            logicalID: try logicalID(10),
            resolutionKind: .applyLeft
        )) {
            try planner.plan(from: ConflictResult(resolutions: [source]))
        }
    }
}
