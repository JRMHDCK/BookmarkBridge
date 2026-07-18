//
//  LogicalDiffError.swift
//  BookmarkBridge
//

nonisolated enum LogicalDiffGraph: Hashable, Codable, Sendable {
    case before
    case after
}

nonisolated enum LogicalDiffError: Error, Hashable, Sendable {
    case duplicateLogicalNode(logicalNodeID: LogicalNodeID, graph: LogicalDiffGraph)
    case inconsistentState(LogicalNodeID)
}
