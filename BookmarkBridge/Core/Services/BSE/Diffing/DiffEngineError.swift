//
//  DiffEngineError.swift
//  BookmarkBridge
//

/// Integrity failures that prevent BSE from describing a diff safely.
nonisolated enum DiffEngineError: Error, Equatable, Sendable {
    case nodeKindChanged(
        logicalID: LogicalNodeID,
        before: NodeKind,
        after: NodeKind
    )
}
