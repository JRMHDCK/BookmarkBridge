//
//  SynchronizationPlan.swift
//  BookmarkBridge
//

nonisolated struct SynchronizationPlan: Hashable, Sendable {
    let phases: [SynchronizationPhase]
    let report: SynchronizationPlanningReport

    var operations: [SynchronizationOperation] {
        phases.flatMap(\.operations)
    }
}
