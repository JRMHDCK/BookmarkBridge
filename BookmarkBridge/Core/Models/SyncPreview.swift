//
//  SyncPreview.swift
//  BookmarkBridge
//

import Foundation

/// The result of a **dry-run**: what a bidirectional sync *would* change on each
/// side, without writing anything.
///
/// Holds one `SyncPlan` per direction (e.g. Safari→Chrome and Chrome→Safari for
/// the additive union). Pure data, shown to the user for explicit consent before
/// any write.
nonisolated struct SyncPreview: Hashable, Sendable {
    let plans: [SyncPlan]

    init(plans: [SyncPlan]) {
        self.plans = plans
    }

    /// True when nothing would change on any side.
    var isEmpty: Bool {
        plans.allSatisfy(\.isEmpty)
    }

    /// Total number of proposed changes across every direction.
    var totalChanges: Int {
        plans.reduce(0) { $0 + $1.count }
    }

    /// The plan that would add to `browser` (the one whose `target` is `browser`).
    func plan(addingTo browser: Browser) -> SyncPlan? {
        plans.first { $0.target == browser }
    }
}
