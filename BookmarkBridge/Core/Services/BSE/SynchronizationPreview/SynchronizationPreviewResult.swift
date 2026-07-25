//
//  SynchronizationPreviewResult.swift
//  BookmarkBridge
//

/// UI-ready summary backed by the existing logical diff and plan models.
/// It intentionally does not duplicate synchronization operations.
nonisolated struct SynchronizationPreviewResult: Hashable, Sendable {
    let request: SynchronizationPreviewRequest
    let direction: ProductionSynchronizationDirection
    let logicalDiff: LogicalDiffResult
    let plan: SynchronizationPlan
    let planFingerprint: SynchronizationPlanFingerprint
    let sourceSnapshotFingerprint: SynchronizationSnapshotFingerprint
    let targetSnapshotFingerprint: SynchronizationSnapshotFingerprint
    let totalOperationCount: Int
    let creationCount: Int
    let deletionCount: Int
    let renameCount: Int
    let moveCount: Int
    let urlModificationCount: Int

    init(
        request: SynchronizationPreviewRequest,
        sourceSnapshot: BSESnapshot,
        targetSnapshot: BSESnapshot,
        logicalDiff: LogicalDiffResult,
        plan: SynchronizationPlan
    ) throws {
        let operations = plan.phases.flatMap(\.operations)
        self.request = request
        direction = request.direction
        self.logicalDiff = logicalDiff
        self.plan = plan
        planFingerprint = try PlanConfirmationFingerprinting.plan(plan)
        sourceSnapshotFingerprint = try PlanConfirmationFingerprinting.snapshot(
            sourceSnapshot
        )
        targetSnapshotFingerprint = try PlanConfirmationFingerprinting.snapshot(
            targetSnapshot
        )
        totalOperationCount = operations.count
        creationCount = operations.count {
            if case .create = $0 { true } else { false }
        }
        deletionCount = operations.count {
            if case .delete = $0 { true } else { false }
        }
        renameCount = operations.count {
            if case .rename = $0 { true } else { false }
        }
        moveCount = operations.count {
            if case .move = $0 { true } else { false }
        }
        urlModificationCount = operations.count {
            if case .updateURL = $0 { true } else { false }
        }
    }
}
