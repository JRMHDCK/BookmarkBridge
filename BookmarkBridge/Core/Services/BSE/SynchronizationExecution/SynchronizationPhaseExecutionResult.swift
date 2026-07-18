//
//  SynchronizationPhaseExecutionResult.swift
//  BookmarkBridge
//

nonisolated enum SynchronizationExecutionPhase: String, Hashable, Codable, Sendable {
    case preparation
    case structural
    case content
    case cleanup
}

nonisolated enum SynchronizationPhaseExecutionStatus: String, Hashable, Codable, Sendable {
    case completed
    case completedWithFailures
    case stoppedOnFailure
    case cancelled
}

nonisolated struct SynchronizationPhaseExecutionResult: Hashable, Sendable {
    let phase: SynchronizationExecutionPhase
    let status: SynchronizationPhaseExecutionStatus
    let operationResults: [SynchronizationOperationExecutionResult]
}
