//
//  SynchronizationPlanningReport.swift
//  BookmarkBridge
//

/// Deterministic diagnostics that never participate in planning decisions.
nonisolated struct SynchronizationPlanningReport: Hashable, Sendable {
    let policy: SynchronizationPolicy
    let inputChangeCount: Int
    let plannedOperationCount: Int
    let skippedChangeCount: Int
    let preparationOperationCount: Int
    let structuralOperationCount: Int
    let contentOperationCount: Int
    let cleanupOperationCount: Int
}
