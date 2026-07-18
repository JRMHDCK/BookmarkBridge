//
//  SynchronizationExecutionResult.swift
//  BookmarkBridge
//

nonisolated struct SynchronizationExecutionResult: Hashable, Sendable {
    let status: SynchronizationExecutionStatus
    let phaseResults: [SynchronizationPhaseExecutionResult]
    let report: SynchronizationExecutionReport

    var operationResults: [SynchronizationOperationExecutionResult] {
        phaseResults.flatMap(\.operationResults)
    }
}
