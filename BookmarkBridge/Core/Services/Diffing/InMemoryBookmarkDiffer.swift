//
//  InMemoryBookmarkDiffer.swift
//  BookmarkBridge
//

import Foundation

/// A placeholder `BookmarkDiffing` used to complete the object graph during the
/// architecture phase.
///
/// It deliberately produces an **empty** plan (the trees are treated as already
/// in sync): real, exhaustively tested diffing logic is intentionally not
/// implemented yet. Replacing this double with the real differ is a later,
/// test-driven step.
nonisolated struct InMemoryBookmarkDiffer: BookmarkDiffing {
    func plan(from source: BookmarkTree, to target: BookmarkTree) -> SyncPlan {
        SyncPlan(source: source.browser, target: target.browser, changes: [])
    }
}
