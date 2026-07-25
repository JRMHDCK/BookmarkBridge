//
//  ProjectionRequest.swift
//  BookmarkBridge
//

/// Fully explicit input for a future target projection.
///
/// `sourceSnapshot` is authoritative and describes the desired state.
/// `targetSnapshot` describes the target's exact current state. Timestamps are
/// retained as snapshot information but never participate in authority.
nonisolated struct ProjectionRequest: Hashable, Sendable {
    let sourceSnapshot: LogicalSnapshot
    let targetSnapshot: LogicalSnapshot
    let policy: SynchronizationPolicy

    init(
        sourceSnapshot: LogicalSnapshot,
        targetSnapshot: LogicalSnapshot,
        policy: SynchronizationPolicy
    ) throws {
        let direction = policy.direction
        guard direction.source != direction.target else {
            throw ProjectionValidationError.identicalSourceAndTarget(
                direction.source
            )
        }
        guard sourceSnapshot.source == direction.source else {
            throw ProjectionValidationError.sourceSnapshotMismatch(
                expected: direction.source,
                actual: sourceSnapshot.source
            )
        }
        guard targetSnapshot.source == direction.target else {
            throw ProjectionValidationError.targetSnapshotMismatch(
                expected: direction.target,
                actual: targetSnapshot.source
            )
        }
        self.sourceSnapshot = sourceSnapshot
        self.targetSnapshot = targetSnapshot
        self.policy = policy
    }
}
