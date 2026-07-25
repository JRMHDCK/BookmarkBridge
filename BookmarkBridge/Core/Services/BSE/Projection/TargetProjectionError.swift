//
//  TargetProjectionError.swift
//  BookmarkBridge
//

nonisolated enum TargetProjectionError: Error, Hashable, Sendable {
    case parentAbsent(logicalNodeID: LogicalNodeID, parentID: LogicalNodeID)
    case cycle(LogicalNodeID)
    case invalidGraph(LogicalNodeID?)
    case projectionImpossible(LogicalNodeID)
    case invalidPermanentRootMutation(LogicalNodeID)
}
