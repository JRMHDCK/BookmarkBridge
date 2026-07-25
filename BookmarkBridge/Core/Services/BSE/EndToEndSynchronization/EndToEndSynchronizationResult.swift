//
//  EndToEndSynchronizationResult.swift
//  BookmarkBridge
//

/// Complete trace of the single write pass and its read-only verification pass.
nonisolated struct EndToEndSynchronizationResult: Hashable, Sendable {
    let sourceRead: EndToEndSynchronizationReadResult
    let targetReadBefore: EndToEndSynchronizationReadResult
    let matchingBefore: MatchingPipelineResult
    let bootstrapBefore: NativeIdentityBootstrapResult
    let projectionBefore: TargetProjection
    let diffBefore: LogicalDiffResult
    let plan: SynchronizationPlan
    let execution: SynchronizationExecutionResult
    let targetReadAfter: EndToEndSynchronizationReadResult
    let matchingAfter: MatchingPipelineResult
    let bootstrapAfter: NativeIdentityBootstrapResult
    let projectionAfter: TargetProjection
    let diffAfter: LogicalDiffResult
}
