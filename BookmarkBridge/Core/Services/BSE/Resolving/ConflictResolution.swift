//
//  ConflictResolution.swift
//  BookmarkBridge
//

/// The only decisions the BSE Conflict Resolver can make.
nonisolated enum ConflictResolutionKind: String, Hashable, Codable, Sendable {
    case applyLeft
    case applyRight
    case applyBoth
    case conflict
    case noAction
}

/// One immutable decision for a logical node.
///
/// Both original diff entries are retained so a later planner can inspect the
/// atomic events and their observed reasons without repeating any analysis.
nonisolated struct ConflictResolution: Hashable, Codable, Sendable, Identifiable {
    let logicalID: LogicalNodeID
    let kind: ConflictResolutionKind
    let reason: ConflictReason
    let leftEntries: [DiffEntry]
    let rightEntries: [DiffEntry]

    var id: LogicalNodeID { logicalID }
    var leftEvents: [BSEEvent] { leftEntries.map(\.event) }
    var rightEvents: [BSEEvent] { rightEntries.map(\.event) }

    init(
        logicalID: LogicalNodeID,
        kind: ConflictResolutionKind,
        reason: ConflictReason,
        leftEntries: [DiffEntry],
        rightEntries: [DiffEntry]
    ) {
        self.logicalID = logicalID
        self.kind = kind
        self.reason = reason
        self.leftEntries = leftEntries
        self.rightEntries = rightEntries
    }
}
