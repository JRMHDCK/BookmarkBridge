//
//  NativeIdentityResolutionError.swift
//  BookmarkBridge
//

nonisolated enum NativeIdentityResolutionError: Error, Hashable, Sendable {
    case observationSourceMismatch(
        expected: BSESourceID,
        actual: BSESourceID
    )
    case duplicateObservation(LogicalNodeID)
    case missingObservation(LogicalNodeID)
    case orphanObservation(LogicalNodeID)
    case duplicateResolvedLogicalNodeID(LogicalNodeID)
    case invalidResolvedSnapshot(BSESourceID)
}
