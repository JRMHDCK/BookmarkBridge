//
//  SynchronizationPreviewSafetyValidatorTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("Synchronization preview safety validator")
struct SynchronizationPreviewSafetyValidatorTests {
    @Test("Blocks mass moves between equivalent normalized folder paths")
    func blocksEquivalentPathChurn() throws {
        let fixture = try safetyFixture(
            moveCount: 100,
            afterFolderTitle: "Favoris"
        )

        #expect(throws: SynchronizationPreviewError.suspiciousStructuralChurn(
            movedCount: 100,
            equivalentPathMoveCount: 100
        )) {
            try SynchronizationPreviewSafetyValidator().validate(
                before: fixture.before,
                after: fixture.after,
                plan: fixture.plan
            )
        }
    }

    @Test("Allows a genuine mass move to a different folder path")
    func allowsGenuineStructuralChange() throws {
        let fixture = try safetyFixture(
            moveCount: 100,
            afterFolderTitle: "Archive"
        )

        try SynchronizationPreviewSafetyValidator().validate(
            before: fixture.before,
            after: fixture.after,
            plan: fixture.plan
        )
    }
}

private func safetyFixture(
    moveCount: Int,
    afterFolderTitle: String
) throws -> (
    before: LogicalStateGraph,
    after: LogicalStateGraph,
    plan: SynchronizationPlan
) {
    let rootID = safetyID(1)
    let beforeFolderID = safetyID(2)
    let afterFolderID = safetyID(3)
    let beforeRoot = try safetyFolder(
        id: rootID,
        title: "Safari Root",
        parentID: nil,
        position: 0,
        rootRole: .primaryBookmarks
    )
    let afterRoot = try safetyFolder(
        id: rootID,
        title: "Chrome Root",
        parentID: nil,
        position: 0,
        rootRole: .primaryBookmarks
    )
    let beforeFolder = try safetyFolder(
        id: beforeFolderID,
        title: "Favoris",
        parentID: rootID,
        position: 0
    )
    let afterFolder = try safetyFolder(
        id: afterFolderID,
        title: afterFolderTitle,
        parentID: rootID,
        position: 0
    )
    let bookmarkIDs = (0..<moveCount).map { safetyID(1_000 + $0) }
    let beforeBookmarks = try bookmarkIDs.enumerated().map {
        try safetyBookmark(
            id: $0.element,
            parentID: beforeFolderID,
            position: $0.offset
        )
    }
    let afterBookmarks = try bookmarkIDs.enumerated().map {
        try safetyBookmark(
            id: $0.element,
            parentID: afterFolderID,
            position: $0.offset
        )
    }
    let beforeNodes = [beforeRoot, beforeFolder] + beforeBookmarks
    let afterNodes = [afterRoot, afterFolder] + afterBookmarks
    let operations = bookmarkIDs.enumerated().map {
        SynchronizationOperation.move(MoveNodeOperation(
            logicalNodeID: $0.element,
            parentID: afterFolderID,
            position: $0.offset
        ))
    }
    let sourceID = BSESourceID(safetyUUID(10))
    let targetID = BSESourceID(safetyUUID(11))
    let policy = SynchronizationPolicy.allChanges(
        direction: .oneWay(source: sourceID, target: targetID)
    )

    return (
        before: try safetyGraph(beforeNodes),
        after: try safetyGraph(afterNodes),
        plan: SynchronizationPlan(
            phases: [.structural(operations)],
            report: SynchronizationPlanningReport(
                policy: policy,
                inputChangeCount: operations.count,
                plannedOperationCount: operations.count,
                skippedChangeCount: 0,
                preparationOperationCount: 0,
                structuralOperationCount: operations.count,
                contentOperationCount: 0,
                cleanupOperationCount: 0
            )
        )
    )
}

private func safetyGraph(
    _ nodes: [LogicalNodeState]
) throws -> LogicalStateGraph {
    try LogicalStateGraph(
        nodes: nodes,
        report: LogicalStateBuildingReport(
            baselineIdentityCount: 0,
            snapshotCount: 1,
            snapshotNodeCount: nodes.count,
            logicalNodeCount: nodes.count,
            structurallyAvailableNodeCount: nodes.count,
            baselineOnlyNodeCount: 0,
            unregisteredNodeCount: nodes.count,
            observationCount: 0
        )
    )
}

private func safetyFolder(
    id: LogicalNodeID,
    title: String,
    parentID: LogicalNodeID?,
    position: Int,
    rootRole: PermanentRootRole? = nil
) throws -> LogicalNodeState {
    try LogicalNodeState(
        logicalNodeID: id,
        kind: .folder,
        permanentRootRole: rootRole,
        title: title,
        url: nil,
        parentID: parentID,
        position: position,
        lifecycle: .unregistered,
        observations: []
    )
}

private func safetyBookmark(
    id: LogicalNodeID,
    parentID: LogicalNodeID,
    position: Int
) throws -> LogicalNodeState {
    try LogicalNodeState(
        logicalNodeID: id,
        kind: .bookmark,
        title: "Bookmark \(position)",
        url: URL(string: "https://example.test/\(position)"),
        parentID: parentID,
        position: position,
        lifecycle: .unregistered,
        observations: []
    )
}

private func safetyID(_ value: Int) -> LogicalNodeID {
    LogicalNodeID(safetyUUID(value))
}

private func safetyUUID(_ value: Int) -> UUID {
    UUID(uuidString: String(
        format: "FA510000-0000-0000-0000-%012d",
        value
    ))!
}
