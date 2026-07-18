//
//  LogicalDiffError.swift
//  BookmarkBridge
//

nonisolated enum LogicalDiffError: Error, Hashable, Sendable {
    case invalidBaseline
    case invalidLogicalSnapshot(BSESourceID)
    case duplicateLogicalNode(logicalNodeID: LogicalNodeID, sourceID: BSESourceID)
    case duplicateObservation(logicalNodeID: LogicalNodeID, sourceID: BSESourceID)
    case inconsistentState(LogicalNodeID)
}
