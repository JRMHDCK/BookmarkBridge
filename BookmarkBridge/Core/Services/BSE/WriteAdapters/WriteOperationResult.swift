//
//  WriteOperationResult.swift
//  BookmarkBridge
//

/// Machine-readable outcome for exactly one atomic operation.
nonisolated struct WriteOperationResult: Hashable, Codable, Sendable {
    let adapterIdentifier: WriteAdapterIdentifier
    let sourceID: BSESourceID
    let logicalNodeID: LogicalNodeID
    let status: WriteOperationStatus
}
