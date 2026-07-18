//
//  SynchronizationExecutionError.swift
//  BookmarkBridge
//

/// Typed failure retained by an operation trace. The executor never retries or
/// translates a failed operation into another operation.
nonisolated enum SynchronizationExecutionError: Error, Hashable, Sendable {
    case unsupportedCapability(WriteAdapterCapability)
    case adapterFailure(WriteAdapterError)
    case unexpectedAdapterFailure(WriteOperationKind)
    case cancelled
}
