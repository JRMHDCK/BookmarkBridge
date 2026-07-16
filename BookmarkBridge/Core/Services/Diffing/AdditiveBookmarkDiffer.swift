//
//  AdditiveBookmarkDiffer.swift
//  BookmarkBridge
//

import Foundation

/// The real, **non-destructive** differ (validated sync semantics).
///
/// `plan(from:to:)` returns only `.add` changes: the bookmarks present in
/// `source` whose URL (by ``BookmarkMatchKey``) is missing from `target`. It
/// never emits `.remove` — no unique favourite can ever be lost. Additions are
/// also de-duplicated among themselves (a URL is added at most once).
///
/// Pure and deterministic: same inputs → same plan, no I/O. This is where the
/// project's data-safety risk is concentrated, so it is exhaustively tested.
///
/// - Note (v1): additions are proposed at the target's root (`parent: nil`);
///   mirroring the source folder structure is a later refinement. Applying a
///   plan (assigning ids, writing) is a separate, later phase — this only
///   *describes* changes.
nonisolated struct AdditiveBookmarkDiffer: BookmarkDiffing {

    init() {}

    func plan(from source: BookmarkTree, to target: BookmarkTree) -> SyncPlan {
        // Every URL already present in the target — additions matched against this.
        var seen = Set(target.allBookmarks.map { BookmarkMatchKey.key(for: $0.url) })

        var changes: [SyncChange] = []
        for bookmark in source.allBookmarks {
            let key = BookmarkMatchKey.key(for: bookmark.url)
            guard !seen.contains(key) else { continue }
            seen.insert(key)   // dedupe additions among themselves
            changes.append(.add(node: .bookmark(bookmark), parent: nil))
        }

        return SyncPlan(source: source.browser, target: target.browser, changes: changes)
    }
}
