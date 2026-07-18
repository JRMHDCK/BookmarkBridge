//
//  BookmarkWriteAdapter.swift
//  BookmarkBridge
//

/// Stateless boundary for executing exactly one already-planned write operation.
/// Sequencing, retries, rollback, and transaction state remain outside adapters.
nonisolated protocol BookmarkWriteAdapter: Sendable {
    var identifier: WriteAdapterIdentifier { get }
    var capabilities: WriteAdapterCapabilities { get }

    func execute(
        operation: SynchronizationOperation,
        context: WriteExecutionContext
    ) async throws -> WriteOperationResult
}
