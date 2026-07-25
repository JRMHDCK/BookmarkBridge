//
//  SynchronizationPipelineRequest.swift
//  BookmarkBridge
//

/// Browser-neutral inputs for one read-only synchronization composition.
nonisolated struct SynchronizationPipelineRequest: Sendable {
    let sourceReader: any EndToEndSynchronizationReading
    let targetReader: any EndToEndSynchronizationReading
    let policy: SynchronizationPolicy
}
