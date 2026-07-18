//
//  MatchingPipelineRequest.swift
//  BookmarkBridge
//

/// Immutable business input for one matching pipeline execution.
nonisolated struct MatchingPipelineRequest: Hashable, Sendable {
    let snapshots: [BSESnapshot]
}
