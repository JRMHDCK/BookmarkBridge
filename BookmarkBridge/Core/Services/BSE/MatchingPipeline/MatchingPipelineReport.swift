//
//  MatchingPipelineReport.swift
//  BookmarkBridge
//

/// Deterministic diagnostics that never participate in pipeline decisions.
nonisolated struct MatchingPipelineReport: Hashable, Codable, Sendable {
    let snapshotCount: Int
    let nodeCount: Int
    let matchingGroupCount: Int
    let matchedGroupCount: Int
    let unmatchedGroupCount: Int
    let ambiguousGroupCount: Int
    let baselineMutationCount: Int
    let baselineTransactionPersisted: Bool
    let baselineRevisionBefore: BaselineRevision
    let baselineRevisionAfter: BaselineRevision
}
