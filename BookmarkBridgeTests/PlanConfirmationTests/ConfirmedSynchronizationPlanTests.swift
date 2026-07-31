//
//  ConfirmedSynchronizationPlanTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("BSE-791 Plan Confirmation")
struct ConfirmedSynchronizationPlanTests {
    @Test("Confirmation preserves the exact previewed plan and fingerprints")
    func validConfirmation() throws {
        let fixture = try makeFixture()

        let confirmed = try ConfirmedSynchronizationPlan(
            confirming: fixture.preview,
            executionRequest: fixture.executionRequest
        )

        #expect(confirmed.direction == fixture.preview.direction)
        #expect(confirmed.plan == fixture.preview.plan)
        #expect(
            confirmed.planFingerprint == fixture.preview.planFingerprint
        )
        #expect(
            confirmed.sourceSnapshotFingerprint
                == fixture.preview.sourceSnapshotFingerprint
        )
        #expect(
            confirmed.targetSnapshotFingerprint
                == fixture.preview.targetSnapshotFingerprint
        )
        try confirmed.validate(against: fixture.preview)
    }

    @Test("Plan fingerprints are deterministic and plan-sensitive")
    func planFingerprintDeterminism() throws {
        let fixture = try makeFixture()
        let first = try PlanConfirmationFingerprinting.plan(
            fixture.preview.plan
        )
        let second = try PlanConfirmationFingerprinting.plan(
            fixture.preview.plan
        )
        let changed = try PlanConfirmationFingerprinting.plan(
            makePlan(
                operations: [
                    .rename(
                        RenameNodeOperation(
                            logicalNodeID: logicalID(2),
                            title: "Changed"
                        )
                    ),
                ]
            )
        )

        #expect(first == second)
        #expect(first.rawValue.count == 64)
        #expect(first != changed)
    }

    @Test("Snapshot fingerprints are deterministic and state-sensitive")
    func snapshotFingerprintDeterminism() throws {
        let fixture = try makeFixture()
        let first = try PlanConfirmationFingerprinting.snapshot(
            fixture.sourceSnapshot
        )
        let second = try PlanConfirmationFingerprinting.snapshot(
            fixture.sourceSnapshot
        )
        let changed = try PlanConfirmationFingerprinting.snapshot(
            makeSnapshot(
                source: fixture.sourceSnapshot.source,
                title: "Changed"
            )
        )

        #expect(first == second)
        #expect(first.rawValue.count == 64)
        #expect(first != changed)
    }

    @Test("A changed plan is rejected")
    func changedPlan() throws {
        let fixture = try makeFixture()
        let confirmed = try ConfirmedSynchronizationPlan(
            confirming: fixture.preview,
            executionRequest: fixture.executionRequest
        )
        let changedPlan = makePlan(
            operations: [
                .rename(
                    RenameNodeOperation(
                        logicalNodeID: logicalID(2),
                        title: "Changed"
                    )
                ),
            ]
        )
        let changedPreview = try SynchronizationPreviewResult(
            request: fixture.preview.request,
            sourceSnapshot: fixture.sourceSnapshot,
            targetSnapshot: fixture.targetSnapshot,
            logicalDiff: fixture.preview.logicalDiff,
            plan: changedPlan
        )

        #expect(throws: PlanConfirmationError.planChanged) {
            try confirmed.validate(against: changedPreview)
        }
    }

    @Test("A changed source or target snapshot is rejected")
    func changedSnapshot() throws {
        let fixture = try makeFixture()
        let confirmed = try ConfirmedSynchronizationPlan(
            confirming: fixture.preview,
            executionRequest: fixture.executionRequest
        )
        let changedSourcePreview = try SynchronizationPreviewResult(
            request: fixture.preview.request,
            sourceSnapshot: makeSnapshot(
                source: fixture.sourceSnapshot.source,
                title: "Changed source"
            ),
            targetSnapshot: fixture.targetSnapshot,
            logicalDiff: fixture.preview.logicalDiff,
            plan: fixture.preview.plan
        )
        let changedTargetPreview = try SynchronizationPreviewResult(
            request: fixture.preview.request,
            sourceSnapshot: fixture.sourceSnapshot,
            targetSnapshot: makeSnapshot(
                source: fixture.targetSnapshot.source,
                title: "Changed target"
            ),
            logicalDiff: fixture.preview.logicalDiff,
            plan: fixture.preview.plan
        )

        #expect(throws: PlanConfirmationError.planChanged) {
            try confirmed.validate(against: changedSourcePreview)
        }
        #expect(throws: PlanConfirmationError.planChanged) {
            try confirmed.validate(against: changedTargetPreview)
        }
    }

    @Test("Confirmation rejects an execution request different from preview")
    func requestMismatch() throws {
        let fixture = try makeFixture()
        let mismatched = ProductionSynchronizationRequest(
            direction: .chromeToSafari,
            safariSourceID: fixture.executionRequest.safariSourceID,
            chromeSourceID: fixture.executionRequest.chromeSourceID,
            safariBookmarksURL:
                fixture.executionRequest.safariBookmarksURL,
            chromeBookmarksURL:
                fixture.executionRequest.chromeBookmarksURL,
            safariBackupDirectoryURL:
                fixture.executionRequest.safariBackupDirectoryURL,
            chromeBackupDirectoryURL:
                fixture.executionRequest.chromeBackupDirectoryURL,
            chromeProfileIdentifier:
                fixture.executionRequest.chromeProfileIdentifier
        )

        #expect(throws: PlanConfirmationError.requestMismatch) {
            _ = try ConfirmedSynchronizationPlan(
                confirming: fixture.preview,
                executionRequest: mismatched
            )
        }
    }

    @Test("Confirmation rejects a different authorized security scope")
    func securityScopeMismatch() throws {
        let fixture = try makeFixture()
        let mismatched = ProductionSynchronizationRequest(
            direction: fixture.executionRequest.direction,
            safariSourceID: fixture.executionRequest.safariSourceID,
            chromeSourceID: fixture.executionRequest.chromeSourceID,
            safariBookmarksURL:
                fixture.executionRequest.safariBookmarksURL,
            chromeBookmarksURL:
                fixture.executionRequest.chromeBookmarksURL,
            safariBackupDirectoryURL:
                fixture.executionRequest.safariBackupDirectoryURL,
            chromeBackupDirectoryURL:
                fixture.executionRequest.chromeBackupDirectoryURL,
            chromeProfileIdentifier:
                fixture.executionRequest.chromeProfileIdentifier,
            safariSecurityScopeURL:
                fixture.executionRequest.safariSecurityScopeURL,
            chromeSecurityScopeURL: URL(
                fileURLWithPath: "/tmp/unconfirmed-chrome-scope"
            )
        )

        #expect(throws: PlanConfirmationError.requestMismatch) {
            _ = try ConfirmedSynchronizationPlan(
                confirming: fixture.preview,
                executionRequest: mismatched
            )
        }
    }

    @Test("Confirmed plan is Hashable and Sendable")
    func valueSemantics() throws {
        let fixture = try makeFixture()
        let confirmed = try ConfirmedSynchronizationPlan(
            confirming: fixture.preview,
            executionRequest: fixture.executionRequest
        )

        requireSendable(confirmed)
        #expect(Set([confirmed, confirmed]).count == 1)
    }
}

private struct ConfirmationFixture {
    let sourceSnapshot: BSESnapshot
    let targetSnapshot: BSESnapshot
    let preview: SynchronizationPreviewResult
    let executionRequest: ProductionSynchronizationRequest
}

private func makeFixture() throws -> ConfirmationFixture {
    let safariSourceID = BSESourceID(confirmationUUID(1))
    let chromeSourceID = BSESourceID(confirmationUUID(2))
    let sourceSnapshot = try makeSnapshot(
        source: safariSourceID,
        title: "Source"
    )
    let targetSnapshot = try makeSnapshot(
        source: chromeSourceID,
        title: "Target"
    )
    let profile = try ChromeProfileIdentifier("Default")
    let previewRequest = SynchronizationPreviewRequest(
        direction: .safariToChrome,
        safariSourceID: safariSourceID,
        chromeSourceID: chromeSourceID,
        safariBookmarksURL: URL(fileURLWithPath: "/tmp/safari-bookmarks"),
        chromeBookmarksURL: URL(fileURLWithPath: "/tmp/chrome-bookmarks"),
        chromeProfileIdentifier: profile
    )
    let executionRequest = ProductionSynchronizationRequest(
        direction: .safariToChrome,
        safariSourceID: safariSourceID,
        chromeSourceID: chromeSourceID,
        safariBookmarksURL: previewRequest.safariBookmarksURL,
        chromeBookmarksURL: previewRequest.chromeBookmarksURL,
        safariBackupDirectoryURL: URL(fileURLWithPath: "/tmp/safari-backups"),
        chromeBackupDirectoryURL: URL(fileURLWithPath: "/tmp/chrome-backups"),
        chromeProfileIdentifier: profile
    )
    let logicalDiff = LogicalDiffResult(
        changes: [],
        report: LogicalDiffReport(
            beforeNodeCount: 1,
            afterNodeCount: 1,
            unchangedNodeCount: 1,
            createdCount: 0,
            deletedCount: 0,
            renamedCount: 0,
            urlChangedCount: 0,
            movedCount: 0,
            reorderedCount: 0,
            lifecycleChangedCount: 0
        )
    )
    let plan = makePlan(operations: [])
    let preview = try SynchronizationPreviewResult(
        request: previewRequest,
        sourceSnapshot: sourceSnapshot,
        targetSnapshot: targetSnapshot,
        logicalDiff: logicalDiff,
        plan: plan
    )
    return ConfirmationFixture(
        sourceSnapshot: sourceSnapshot,
        targetSnapshot: targetSnapshot,
        preview: preview,
        executionRequest: executionRequest
    )
}

private func makeSnapshot(
    source: BSESourceID,
    title: String
) throws -> BSESnapshot {
    BSESnapshot(
        source: source,
        capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
        tree: try BSETree(
            nodes: [
                try BSENode(
                    logicalID: logicalID(1),
                    kind: .folder,
                    title: title,
                    position: 0
                ),
            ]
        )
    )
}

private func makePlan(
    operations: [SynchronizationOperation]
) -> SynchronizationPlan {
    let direction = SynchronizationDirection.oneWay(
        source: BSESourceID(confirmationUUID(1)),
        target: BSESourceID(confirmationUUID(2))
    )
    return SynchronizationPlan(
        phases: [
            .preparation([]),
            .structural([]),
            .content(operations),
            .cleanup([]),
        ],
        report: SynchronizationPlanningReport(
            policy: .allChanges(direction: direction),
            inputChangeCount: operations.count,
            plannedOperationCount: operations.count,
            skippedChangeCount: 0,
            preparationOperationCount: 0,
            structuralOperationCount: 0,
            contentOperationCount: operations.count,
            cleanupOperationCount: 0
        )
    )
}

private func logicalID(_ value: Int) -> LogicalNodeID {
    LogicalNodeID(confirmationUUID(value))
}

private func confirmationUUID(_ value: Int) -> UUID {
    UUID(uuid: (
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, UInt8(truncatingIfNeeded: value)
    ))
}

private func requireSendable<T: Sendable>(_: T) {}
