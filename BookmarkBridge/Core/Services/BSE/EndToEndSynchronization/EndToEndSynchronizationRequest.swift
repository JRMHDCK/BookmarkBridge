//
//  EndToEndSynchronizationRequest.swift
//  BookmarkBridge
//

/// Explicit policy and write consent for one complete synchronization.
nonisolated struct EndToEndSynchronizationRequest: Hashable, Sendable {
    let synchronizationPolicy: SynchronizationPolicy
    let writeContext: WriteExecutionContext
    let executionPolicy: SynchronizationExecutionPolicy
}
