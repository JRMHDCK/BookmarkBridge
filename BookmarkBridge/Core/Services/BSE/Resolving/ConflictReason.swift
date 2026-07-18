//
//  ConflictReason.swift
//  BookmarkBridge
//

/// The explicit fact that led the resolver to one decision.
nonisolated enum ConflictReason: Hashable, Codable, Sendable {
    case changedOnlyInLeft
    case changedOnlyInRight
    case identicalChanges
    case compatibleRenameAndMove
    case concurrentRename
    case concurrentMove
    case deleteVsModify
    case urlConflict
    case alreadyConsistent
    case incompatibleChanges
}
