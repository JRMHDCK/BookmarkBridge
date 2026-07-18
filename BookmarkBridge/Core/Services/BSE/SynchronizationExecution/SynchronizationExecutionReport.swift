//
//  SynchronizationExecutionReport.swift
//  BookmarkBridge
//

/// Deterministic aggregate diagnostics. Counts never influence execution.
nonisolated struct SynchronizationExecutionReport: Hashable, Sendable {
    let plannedOperationCount: Int
    let attemptedOperationCount: Int
    let refusedOperationCount: Int
    let appliedOperationCount: Int
    let alreadySatisfiedOperationCount: Int
    let simulatedOperationCount: Int
    let failedOperationCount: Int
    let cancelledOperationCount: Int
    let completedPhaseCount: Int
}
