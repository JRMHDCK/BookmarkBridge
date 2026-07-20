//
//  SynchronizationPlanningRequest.swift
//  BookmarkBridge
//

nonisolated struct SynchronizationPlanningRequest: Hashable, Sendable {
    let before: LogicalStateGraph
    let logicalDiff: LogicalDiffResult
    let policy: SynchronizationPolicy
}
