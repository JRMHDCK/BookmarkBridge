//
//  WriteAdapterError.swift
//  BookmarkBridge
//

/// Generic, typed failures with no browser-specific payload.
nonisolated enum WriteAdapterError: Error, Hashable, Codable, Sendable {
    case permissionDenied(sourceID: BSESourceID)
    case sourceUnavailable(sourceID: BSESourceID)
    case sourceMismatch(expected: BSESourceID, actual: BSESourceID)
    case unsupportedCapability(WriteAdapterCapability)
    case unsupportedExecutionMode(WriteExecutionMode)
    case invalidOperation(WriteOperationKind)
    case executionFailed(WriteOperationKind)
}
