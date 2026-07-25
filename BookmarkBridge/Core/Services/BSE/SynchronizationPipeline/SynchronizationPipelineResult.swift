//
//  SynchronizationPipelineResult.swift
//  BookmarkBridge
//

/// Shared read-only analysis used both for planning and final verification.
nonisolated struct SynchronizationPipelineAnalysis: Hashable, Sendable {
    let sourceRead: EndToEndSynchronizationReadResult
    let targetRead: EndToEndSynchronizationReadResult
    let matching: MatchingPipelineResult
    let reconciliationReport: IdentityReconciliationReport
    let bootstrap: NativeIdentityBootstrapResult
    let projection: TargetProjection
    let logicalDiff: LogicalDiffResult
}

/// Complete read-only composition result. It is safe to display or confirm,
/// but does not execute, persist, or validate a synchronization.
nonisolated struct SynchronizationPipelineResult: Hashable, Sendable {
    let analysis: SynchronizationPipelineAnalysis
    let plan: SynchronizationPlan

    var sourceRead: EndToEndSynchronizationReadResult {
        analysis.sourceRead
    }

    var targetRead: EndToEndSynchronizationReadResult {
        analysis.targetRead
    }

    var matching: MatchingPipelineResult {
        analysis.matching
    }

    var reconciliationReport: IdentityReconciliationReport {
        analysis.reconciliationReport
    }

    var bootstrap: NativeIdentityBootstrapResult {
        analysis.bootstrap
    }

    var projection: TargetProjection {
        analysis.projection
    }

    var logicalDiff: LogicalDiffResult {
        analysis.logicalDiff
    }
}
