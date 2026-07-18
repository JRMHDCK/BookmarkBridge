//
//  LogicalDiffReport.swift
//  BookmarkBridge
//

/// Deterministic diagnostics that never participate in diff decisions.
nonisolated struct LogicalDiffReport: Hashable, Codable, Sendable {
    let beforeNodeCount: Int
    let afterNodeCount: Int
    let unchangedNodeCount: Int
    let createdCount: Int
    let deletedCount: Int
    let renamedCount: Int
    let urlChangedCount: Int
    let movedCount: Int
    let reorderedCount: Int
    let lifecycleChangedCount: Int

    var changeCount: Int {
        createdCount
            + deletedCount
            + renamedCount
            + urlChangedCount
            + movedCount
            + reorderedCount
            + lifecycleChangedCount
    }
}
