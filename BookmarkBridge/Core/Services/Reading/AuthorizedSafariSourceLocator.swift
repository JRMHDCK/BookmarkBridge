//
//  AuthorizedSafariSourceLocator.swift
//  BookmarkBridge
//

import Foundation

/// Provides the **authorized** location of Safari's bookmark file by resolving a
/// persisted security-scoped bookmark.
///
/// It orchestrates three single-responsibility collaborators and nothing else:
/// - `BookmarkStore` — load / save the bookmark blob;
/// - `SecurityScopedBookmarkResolving` — turn the blob into a URL (+ staleness);
/// - `SecurityScopedBookmarkCreating` — recreate the blob when it is stale.
///
/// It performs **no file access**, contains **no UI**, and never calls
/// `NSOpenPanel`. Obtaining a first authorization from the user is delegated to
/// `SafariAccessCoordinator`. It is fully independent of the reader and decoder.
///
/// Behaviour of `locate(_:)`:
/// - valid bookmark → returns the resolved location;
/// - stale but resolvable → refreshes the stored bookmark (best-effort) and
///   returns the resolved location;
/// - absent, corrupted, revoked, or unresolvable → `authorizationRequired`.
nonisolated struct AuthorizedSafariSourceLocator: BookmarkSourceLocating {
    private let store: BookmarkStore
    private let resolver: SecurityScopedBookmarkResolving
    private let creator: SecurityScopedBookmarkCreating

    init(
        store: BookmarkStore,
        resolver: SecurityScopedBookmarkResolving,
        creator: SecurityScopedBookmarkCreating
    ) {
        self.store = store
        self.resolver = resolver
        self.creator = creator
    }

    func locate(_ browser: Browser) throws -> BrowserLocation {
        guard browser == .safari else {
            throw BookmarkError.unsupportedBrowser(browser)
        }

        // Absent or corrupted stored data → the user must (re)authorize.
        guard let data = try? store.loadBookmark(for: .safari) else {
            throw BookmarkError.authorizationRequired(.safari)
        }

        // Unresolvable / revoked bookmark → the user must (re)authorize.
        let resolved: ResolvedBookmark
        do {
            resolved = try resolver.resolve(data)
        } catch {
            throw BookmarkError.authorizationRequired(.safari)
        }

        if resolved.isStale {
            refreshBookmark(for: resolved.url)
        }

        return BrowserLocation(browser: .safari, fileURL: resolved.url)
    }

    /// Recreates and re-persists the bookmark for a stale entry. Best-effort:
    /// the current read still succeeds via the resolved URL even if refreshing
    /// fails, so a transient persistence problem never blocks a read.
    private func refreshBookmark(for url: URL) {
        guard let refreshed = try? creator.makeBookmark(for: url) else { return }
        try? store.saveBookmark(refreshed, for: .safari)
    }
}
