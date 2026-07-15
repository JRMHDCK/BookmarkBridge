//
//  SecurityScopedBookmarkResolving.swift
//  BookmarkBridge
//

import Foundation

/// The result of resolving bookmark data: the URL and whether the bookmark is
/// stale and should be recreated.
nonisolated struct ResolvedBookmark: Sendable, Equatable {
    let url: URL
    let isStale: Bool

    init(url: URL, isStale: Bool) {
        self.url = url
        self.isStale = isStale
    }
}

/// Resolves persisted security-scoped bookmark `Data` back into a URL.
///
/// Single responsibility: turn bookmark `Data` into a `ResolvedBookmark`. It
/// does not read files, persist anything, or decide what to do when a bookmark
/// is stale — the caller (e.g. `AuthorizedSafariSourceLocator`) decides whether
/// to refresh and re-save.
nonisolated protocol SecurityScopedBookmarkResolving: Sendable {
    func resolve(_ data: Data) throws -> ResolvedBookmark
}

/// Production implementation over Foundation's bookmark API.
nonisolated struct SystemSecurityScopedBookmarkResolver: SecurityScopedBookmarkResolving {
    init() {}

    func resolve(_ data: Data) throws -> ResolvedBookmark {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        return ResolvedBookmark(url: url, isStale: isStale)
    }
}
