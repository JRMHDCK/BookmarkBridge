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
/// Each `.add` carries the bookmark's **origin folder path** (`sourcePath`, root →
/// parent) so the folder structure can be recreated at write time. The concrete
/// destination `parent` is left `nil` for now (resolved when the target tree is
/// rebuilt); applying a plan is a separate, later phase — this only *describes*
/// changes.
nonisolated struct AdditiveBookmarkDiffer: BookmarkDiffing {

    init() {}

    func plan(from source: BookmarkTree, to target: BookmarkTree) -> SyncPlan {
        // Every URL already present in the target — additions matched against this.
        var seen = Set(target.allBookmarks.map { BookmarkMatchKey.key(for: $0.url) })

        var changes: [SyncChange] = []
        for root in source.roots {
            collectAdditions(from: .folder(root), path: [], seen: &seen, into: &changes)
        }

        return SyncPlan(source: source.browser, target: target.browser, changes: changes)
    }

    /// Depth-first walk that records, for each missing bookmark, an `.add` change
    /// carrying the ancestor folders traversed to reach it. Uses plain loops and
    /// recursion (no escaping closures).
    private func collectAdditions(
        from node: BookmarkNode,
        path: [BookmarkPathComponent],
        seen: inout Set<String>,
        into changes: inout [SyncChange]
    ) {
        switch node {
        case .bookmark(let bookmark):
            let key = BookmarkMatchKey.key(for: bookmark.url)
            guard !seen.contains(key) else { return }
            seen.insert(key)   // dedupe additions among themselves
            changes.append(.add(node: node, parent: nil, sourcePath: path))
        case .folder(let folder):
            let childPath = path + [BookmarkPathComponent(id: folder.id, title: folder.title)]
            for child in folder.children {
                collectAdditions(from: child, path: childPath, seen: &seen, into: &changes)
            }
        }
    }
}
