//
//  SynchronizationExecutionRequest.swift
//  BookmarkBridge
//

/// Immutable execution inputs. The adapter owns no sequencing state.
nonisolated struct SynchronizationExecutionRequest: Sendable {
    let plan: SynchronizationPlan
    let adapter: any BookmarkWriteAdapter
    let context: WriteExecutionContext
    let policy: SynchronizationExecutionPolicy
}
