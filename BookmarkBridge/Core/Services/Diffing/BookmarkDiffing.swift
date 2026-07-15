//
//  BookmarkDiffing.swift
//  BookmarkBridge
//

import Foundation

/// Computes a `SyncPlan` describing how to reconcile two trees.
///
/// Pure and deterministic: same inputs → same plan, no side effects, no I/O.
/// This makes diffing exhaustively unit-testable, which matters because it is
/// where the project's data-safety risk is concentrated.
nonisolated protocol BookmarkDiffing: Sendable {
    /// Produces the changes that would make `target` match `source`.
    func plan(from source: BookmarkTree, to target: BookmarkTree) -> SyncPlan
}
