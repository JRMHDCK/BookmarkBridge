//
//  BSEAdapterError.swift
//  BookmarkBridge
//

/// Generic, machine-readable failures at the BSE adapter boundary.
nonisolated enum BSEAdapterError: Error, Hashable, Codable, Sendable {
    case permissionDenied(sourceID: BSESourceID)
    case permissionNotDetermined(sourceID: BSESourceID)
    case sourceUnavailable(sourceID: BSESourceID)
    case unsupportedVersion(sourceID: BSESourceID)
    case untestedVersion(sourceID: BSESourceID)
    case unsupportedCapability(BSEAdapterCapability)
    case invalidExecutionStep(ExecutionStepKind)
    case executionFailed(ExecutionStepKind)
    case verificationFailed(ExecutionStepKind)
    case restorePointCreationFailed(sourceID: BSESourceID)
    case restorationFailed(restorePointID: BSEAdapterRestorePointID)
    case sourceMismatch(expected: BSESourceID, actual: BSESourceID)
}
