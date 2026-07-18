//
//  MatchingPipelineResult.swift
//  BookmarkBridge
//

/// Complete business output. Baseline commands remain an internal transaction
/// detail and are intentionally absent from this API.
nonisolated struct MatchingPipelineResult: Hashable, Sendable {
    let baselineBefore: Baseline
    let baselineAfter: Baseline
    let logicalSnapshots: [LogicalSnapshot]
    let reconciliationReport: IdentityReconciliationReport
    let pipelineReport: MatchingPipelineReport
}
