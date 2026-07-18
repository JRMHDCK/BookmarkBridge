//
//  LogicalStateBuildingRequest.swift
//  BookmarkBridge
//

nonisolated struct LogicalStateBuildingRequest: Hashable, Sendable {
    let baseline: Baseline
    let logicalSnapshots: [LogicalSnapshot]
}
