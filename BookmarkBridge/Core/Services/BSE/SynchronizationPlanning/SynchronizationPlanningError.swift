//
//  SynchronizationPlanningError.swift
//  BookmarkBridge
//

nonisolated enum SynchronizationPlanningError: Error, Hashable, Sendable {
    case invalidLogicalDiff
    case invalidSynchronizationPolicy
    case unsupportedChange(LogicalNodeID)
    case inconsistentPlan
}
