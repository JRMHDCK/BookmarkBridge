//
//  BookmarkSearchEngine.swift
//  BookmarkBridge
//

import Foundation

/// The default `BookmarkSearching` implementation: a single depth-first pass
/// over each in-memory tree, matching titles, hosts, URLs and folder names.
///
/// - Read-only: it never reads a file; it only walks trees it is handed.
/// - Case- and diacritic-insensitive (see ``normalize(_:)``).
/// - Linear in the number of nodes, so it stays instant on several thousand
///   bookmarks.
nonisolated struct BookmarkSearchEngine: BookmarkSearching {

    init() {}

    func search(_ query: String, in sources: [SearchableSource]) -> [BookmarkSearchResult] {
        let normalizedQuery = Self.normalize(query)
        guard !normalizedQuery.isEmpty else { return [] }

        var results: [BookmarkSearchResult] = []
        for scope in sources {
            for root in scope.tree.roots {
                Self.collect(.folder(root), source: scope.source, ancestors: [], query: normalizedQuery, into: &results)
            }
        }
        return results.sorted(by: Self.isOrderedBefore)
    }

    // MARK: - Traversal

    /// Depth-first walk: record a hit for the node when it matches, then recurse
    /// into a folder's children with the folder appended to the ancestor chain.
    private static func collect(
        _ node: BookmarkNode,
        source: BookmarkSource,
        ancestors: [BookmarkPathComponent],
        query: String,
        into results: inout [BookmarkSearchResult]
    ) {
        switch node {
        case .bookmark(let bookmark):
            if let relevance = bookmarkRelevance(bookmark, query: query) {
                results.append(BookmarkSearchResult(source: source, node: node, path: ancestors, relevance: relevance))
            }
        case .folder(let folder):
            if let relevance = titleRelevance(folder.title, query: query) {
                results.append(BookmarkSearchResult(source: source, node: node, path: ancestors, relevance: relevance))
            }
            let childAncestors = ancestors + [BookmarkPathComponent(id: folder.id, title: folder.title)]
            for child in folder.children {
                collect(child, source: source, ancestors: childAncestors, query: query, into: &results)
            }
        }
    }

    // MARK: - Matching

    /// A bookmark matches on its title first (which sets the strongest
    /// relevance), then on its host or full URL (ranked as "other").
    private static func bookmarkRelevance(_ bookmark: Bookmark, query: String) -> BookmarkSearchRelevance? {
        if let titleRelevance = titleRelevance(bookmark.title, query: query) {
            return titleRelevance
        }
        let host = normalize(bookmark.url.host() ?? "")
        let fullURL = normalize(bookmark.url.absoluteString)
        if host.contains(query) || fullURL.contains(query) {
            return .other
        }
        return nil
    }

    /// Relevance of a title (also used for folder names): exact, prefix, or
    /// substring, or `nil` when it does not match at all.
    private static func titleRelevance(_ title: String, query: String) -> BookmarkSearchRelevance? {
        let normalizedTitle = normalize(title)
        if normalizedTitle == query { return .exactTitle }
        if normalizedTitle.hasPrefix(query) { return .titlePrefix }
        if normalizedTitle.contains(query) { return .other }
        return nil
    }

    // MARK: - Normalization

    /// Case- and diacritic-insensitive folding, trimmed of surrounding
    /// whitespace, so "  Café " and "cafe" compare equal.
    static func normalize(_ string: String) -> String {
        string
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Ordering

    /// Rank by relevance, then alphabetically by title, then by source name, then
    /// by stable id — fully deterministic, independent of traversal order.
    private static func isOrderedBefore(_ lhs: BookmarkSearchResult, _ rhs: BookmarkSearchResult) -> Bool {
        if lhs.relevance != rhs.relevance {
            return lhs.relevance < rhs.relevance
        }
        let lhsTitle = normalize(lhs.title)
        let rhsTitle = normalize(rhs.title)
        if lhsTitle != rhsTitle {
            return lhsTitle < rhsTitle
        }
        if lhs.source.displayName != rhs.source.displayName {
            return lhs.source.displayName < rhs.source.displayName
        }
        return lhs.id < rhs.id
    }
}
