//
//  BookmarkSearching.swift
//  BookmarkBridge
//

import Foundation

/// A source paired with the tree already read for it — the input to a search.
///
/// Searching never touches the filesystem: it works only on trees that were read
/// earlier and kept in memory, honoring the read-only guarantee.
nonisolated struct SearchableSource: Hashable, Sendable {
    let source: BookmarkSource
    let tree: BookmarkTree

    init(source: BookmarkSource, tree: BookmarkTree) {
        self.source = source
        self.tree = tree
    }
}

/// Searches across already-loaded bookmark trees.
///
/// A pure, read-only contract: given a query and the in-memory sources, it
/// returns ranked results and performs no I/O. Depending on this protocol (not a
/// concrete engine) keeps the search UI testable via mocks.
nonisolated protocol BookmarkSearching: Sendable {
    /// Returns the results matching `query` across `sources`, ranked best-first.
    /// An empty or whitespace-only query yields no results.
    func search(_ query: String, in sources: [SearchableSource]) -> [BookmarkSearchResult]
}
