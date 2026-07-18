//
//  LogicalDiffRequest.swift
//  BookmarkBridge
//

nonisolated struct LogicalDiffRequest: Hashable, Sendable {
    let baseline: Baseline
    let logicalSnapshots: [LogicalSnapshot]
}
