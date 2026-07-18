//
//  SynchronizationPlanningRequest.swift
//  BookmarkBridge
//

nonisolated struct SynchronizationPlanningRequest: Hashable, Sendable {
    let logicalDiff: LogicalDiffResult
    let policy: SynchronizationPolicy
}
