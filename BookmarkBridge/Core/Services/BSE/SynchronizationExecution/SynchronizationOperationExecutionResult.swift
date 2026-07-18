//
//  SynchronizationOperationExecutionResult.swift
//  BookmarkBridge
//

nonisolated enum SynchronizationOperationExecutionStatus: String, Hashable, Codable, Sendable {
    case applied
    case alreadySatisfied
    case simulated
    case failed
    case refused
    case cancelled
}

/// Trace for one operation that was invoked or refused before adapter access.
nonisolated struct SynchronizationOperationExecutionResult: Hashable, Sendable {
    let operation: SynchronizationOperation
    let status: SynchronizationOperationExecutionStatus
    let adapterResult: WriteOperationResult?
    let error: SynchronizationExecutionError?
}
