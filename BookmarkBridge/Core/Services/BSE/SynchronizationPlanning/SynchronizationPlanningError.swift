//
//  SynchronizationPlanningError.swift
//  BookmarkBridge
//

nonisolated enum SynchronizationPlanningError: Error, Hashable, Sendable {
    case invalidLogicalDiff
    case invalidSynchronizationPolicy
    case unsupportedChange(LogicalNodeID)
    case missingDeletedNode(LogicalNodeID)
    case missingParent(logicalNodeID: LogicalNodeID, parentID: LogicalNodeID)
    case parentCycle(LogicalNodeID)
    case unresolvableOperationDependency([LogicalNodeID])
    case unresolvablePositionDependency([LogicalNodeID])
    case invalidPermanentRootMutation(LogicalNodeID)
    case inconsistentPlan
}
