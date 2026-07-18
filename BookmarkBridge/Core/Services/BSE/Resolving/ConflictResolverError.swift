//
//  ConflictResolverError.swift
//  BookmarkBridge
//

/// Identifies which precomputed diff contains an integrity failure.
nonisolated enum ConflictResolverSide: String, Hashable, Codable, Sendable {
    case left
    case right
}

/// Input failures that prevent deterministic conflict resolution.
nonisolated enum ConflictResolverError: Error, Equatable, Sendable {
    case duplicateEvent(
        logicalID: LogicalNodeID,
        kind: BSEEventKind,
        side: ConflictResolverSide
    )
    case invalidEventSequence(
        logicalID: LogicalNodeID,
        side: ConflictResolverSide
    )
}
