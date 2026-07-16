//
//  BookmarkSyncPlanner.swift
//  BookmarkBridge
//

import Foundation

/// Produces a read-only, bidirectional **dry-run** of a sync between two trees.
///
/// It runs the injected `BookmarkDiffing` in both directions and packages the
/// resulting plans as a `SyncPreview` — what would be added to each side to reach
/// the additive union. Pure and side-effect-free: nothing is written, no I/O.
/// Applying a preview (backup, writing) is a later, separate phase.
nonisolated struct BookmarkSyncPlanner {
    private let differ: any BookmarkDiffing

    init(differ: any BookmarkDiffing = AdditiveBookmarkDiffer()) {
        self.differ = differ
    }

    /// The dry-run preview reconciling `a` and `b` (both directions).
    func preview(between a: BookmarkTree, and b: BookmarkTree) -> SyncPreview {
        SyncPreview(plans: [
            differ.plan(from: a, to: b),
            differ.plan(from: b, to: a),
        ])
    }
}
