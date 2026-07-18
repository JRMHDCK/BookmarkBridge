//
//  LogicalDiffRequest.swift
//  BookmarkBridge
//

nonisolated struct LogicalDiffRequest: Hashable, Sendable {
    let before: LogicalStateGraph
    let after: LogicalStateGraph
}
