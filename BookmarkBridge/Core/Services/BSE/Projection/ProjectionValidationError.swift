//
//  ProjectionValidationError.swift
//  BookmarkBridge
//

nonisolated enum ProjectionValidationError: Error, Hashable, Sendable {
    case identicalSourceAndTarget(BSESourceID)
    case sourceSnapshotMismatch(expected: BSESourceID, actual: BSESourceID)
    case targetSnapshotMismatch(expected: BSESourceID, actual: BSESourceID)
}
