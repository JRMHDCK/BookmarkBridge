//
//  ExecutionStep.swift
//  BookmarkBridge
//

/// The only atomic operations an eventual BSE transaction may execute.
nonisolated enum ExecutionStepKind: String, Hashable, Codable, Sendable {
    case create
    case delete
    case move
    case rename
}

/// One immutable, traceable operation selected by the Planner.
///
/// The complete source resolution is retained, preserving the chain from this
/// step through `ConflictResolution`, `DiffEntry`, and `BSEEvent`.
nonisolated struct ExecutionStep: Hashable, Codable, Sendable {
    let kind: ExecutionStepKind
    let logicalID: LogicalNodeID
    let entry: DiffEntry
    let resolution: ConflictResolution

    var event: BSEEvent { entry.event }

    init(
        kind: ExecutionStepKind,
        logicalID: LogicalNodeID,
        entry: DiffEntry,
        resolution: ConflictResolution
    ) {
        self.kind = kind
        self.logicalID = logicalID
        self.entry = entry
        self.resolution = resolution
    }
}
