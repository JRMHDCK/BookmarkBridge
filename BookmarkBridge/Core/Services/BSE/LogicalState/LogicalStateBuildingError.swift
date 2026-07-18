//
//  LogicalStateBuildingError.swift
//  BookmarkBridge
//

nonisolated enum LogicalStateBuildingError: Error, Hashable, Sendable {
    case invalidBaseline
    case invalidLogicalSnapshot(BSESourceID)
    case duplicateLogicalNode(logicalNodeID: LogicalNodeID, sourceID: BSESourceID)
    case inconsistentGraph(LogicalNodeID)
    case missingParent(logicalNodeID: LogicalNodeID, parentID: LogicalNodeID)
}
