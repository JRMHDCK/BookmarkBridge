//
//  SyncPlan.swift
//  BookmarkBridge
//

import Foundation

/// An ordered, side-effect-free description of how to make `target` match
/// `source`.
///
/// Produced by `BookmarkDiffing`. A plan is pure data: it is previewed to the
/// user (dry-run) before anything is ever written.
nonisolated struct SyncPlan: Hashable, Sendable {
    let source: Browser
    let target: Browser
    let changes: [SyncChange]

    init(source: Browser, target: Browser, changes: [SyncChange]) {
        self.source = source
        self.target = target
        self.changes = changes
    }

    /// A plan with no changes: the two trees already agree.
    var isEmpty: Bool { changes.isEmpty }

    /// Number of proposed changes.
    var count: Int { changes.count }
}
