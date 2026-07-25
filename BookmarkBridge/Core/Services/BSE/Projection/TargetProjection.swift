//
//  TargetProjection.swift
//  BookmarkBridge
//

/// Source-specific current and desired states ready for logical diffing.
nonisolated struct TargetProjection: Hashable, Sendable {
    let before: LogicalStateGraph
    let after: LogicalStateGraph
}
