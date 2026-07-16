//
//  BookmarkSearchResult.swift
//  BookmarkBridge
//

import Foundation

/// How well a result matches the query, from strongest to weakest. Lower raw
/// values rank first: an exact title beats a title prefix, which beats any other
/// match (title substring, host, URL, or folder name).
nonisolated enum BookmarkSearchRelevance: Int, Comparable, Sendable {
    case exactTitle = 0
    case titlePrefix = 1
    case other = 2

    static func < (lhs: BookmarkSearchRelevance, rhs: BookmarkSearchRelevance) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A single search hit: the matched node, the source it belongs to, the chain of
/// ancestor folders leading to it, and how strongly it matched.
///
/// Immutable value — the search engine produces these from in-memory trees; the
/// UI reads them without any further I/O.
nonisolated struct BookmarkSearchResult: Identifiable, Hashable, Sendable {
    /// The source (browser/profile) this hit was found in.
    let source: BookmarkSource
    /// The matched node itself (bookmark or folder).
    let node: BookmarkNode
    /// Ancestor folders from a root down to the node's parent (empty if the node
    /// is a root folder).
    let path: [BookmarkPathComponent]
    /// How strongly this hit matched, used for ranking.
    let relevance: BookmarkSearchRelevance

    init(source: BookmarkSource, node: BookmarkNode, path: [BookmarkPathComponent], relevance: BookmarkSearchRelevance) {
        self.source = source
        self.node = node
        self.path = path
        self.relevance = relevance
    }

    /// Whether the matched node is a folder.
    var isFolder: Bool { node.isFolder }

    /// The matched node's display title.
    var title: String { node.title }

    /// The bookmark URL, or `nil` when the hit is a folder.
    var url: URL? {
        if case .bookmark(let bookmark) = node { bookmark.url } else { nil }
    }

    /// The bookmark host, or `nil` when the hit is a folder or has no host.
    var host: String? { url?.host() }

    /// Stable identity, unique across sources and duplicate node ids (the same
    /// node id may appear in different profiles or folders).
    var id: String {
        let trail = path.map(\.id.rawValue).joined(separator: "/")
        return "\(source.id.browser.rawValue)|\(source.id.profile ?? "")|\(trail)|\(node.id.rawValue)"
    }
}
