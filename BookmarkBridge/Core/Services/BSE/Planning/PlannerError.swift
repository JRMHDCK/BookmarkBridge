//
//  PlannerError.swift
//  BookmarkBridge
//

/// Integrity failures that prevent a safe, deterministic execution plan.
nonisolated enum PlannerError: Error, Equatable, Sendable {
    case missingSelectedEntries(
        logicalID: LogicalNodeID,
        resolutionKind: ConflictResolutionKind
    )
    case entryIdentifierMismatch(
        expected: LogicalNodeID,
        actual: LogicalNodeID
    )
    case contradictoryEvents(
        logicalID: LogicalNodeID,
        kind: ExecutionStepKind
    )
    case cyclicDependencies(
        kind: ExecutionStepKind,
        logicalIDs: [LogicalNodeID]
    )
}
