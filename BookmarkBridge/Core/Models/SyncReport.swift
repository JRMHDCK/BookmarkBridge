//
//  SyncReport.swift
//  BookmarkBridge
//

import Foundation

/// The outcome of running a `SyncPlan`.
///
/// In a dry-run, `wasDryRun` is `true` and nothing was written: the report
/// simply states what *would* happen. Dry-run is the default, per the
/// "read-only before write" principle.
nonisolated struct SyncReport: Hashable, Sendable {
    let plan: SyncPlan
    let applied: [SyncChange]
    let skipped: [SyncChange]
    let wasDryRun: Bool
    let finishedAt: Date

    init(
        plan: SyncPlan,
        applied: [SyncChange],
        skipped: [SyncChange],
        wasDryRun: Bool,
        finishedAt: Date
    ) {
        self.plan = plan
        self.applied = applied
        self.skipped = skipped
        self.wasDryRun = wasDryRun
        self.finishedAt = finishedAt
    }
}
