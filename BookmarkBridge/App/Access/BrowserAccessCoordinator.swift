//
//  BrowserAccessCoordinator.swift
//  BookmarkBridge
//

import Foundation

/// Coordinates the one-time access authorization flow for a browser (Safari file
/// or Chrome directory).
///
/// It **only** authorizes; it never decodes favourites, opens or reads the
/// target, builds a `BookmarkTree`, parses anything, or depends on a reader. Its
/// single job is: obtain permission, validate the selection, create a read-only
/// security-scoped bookmark, persist it (keyed by browser), and return the URL.
@MainActor
struct BrowserAccessCoordinator {
    /// Expected trailing path of Safari's bookmarks file.
    static let safariPathSuffix = "Library/Safari/Bookmarks.plist"
    /// Expected trailing path of Chrome's data directory.
    static let chromeDirectorySuffix = "Google/Chrome"

    let browser: Browser
    let expectedPathSuffix: String

    private let authorizer: any AccessAuthorizing
    private let creator: SecurityScopedBookmarkCreating
    private let store: BookmarkStore

    init(
        browser: Browser,
        expectedPathSuffix: String,
        authorizer: any AccessAuthorizing,
        creator: SecurityScopedBookmarkCreating,
        store: BookmarkStore
    ) {
        self.browser = browser
        self.expectedPathSuffix = expectedPathSuffix
        self.authorizer = authorizer
        self.creator = creator
        self.store = store
    }

    @discardableResult
    func authorize() async throws -> URL {
        // 1. Ask the user (cancellation propagates as AccessError.cancelled).
        let url = try await authorizer.requestAccess()

        // 2. Never silently accept the wrong selection. Tolerant of a trailing
        //    slash on directory URLs.
        var path = url.path(percentEncoded: false)
        if path.hasSuffix("/") { path.removeLast() }
        guard path.hasSuffix(expectedPathSuffix) else {
            throw AccessError.wrongFile(selected: url)
        }

        // 3. Create a read-only security-scoped bookmark.
        let bookmark: Data
        do {
            bookmark = try creator.makeBookmark(for: url)
        } catch {
            throw AccessError.bookmarkCreationFailed
        }

        // 4. Persist it, keyed by browser.
        do {
            try store.saveBookmark(bookmark, for: browser)
        } catch {
            throw AccessError.persistenceFailed
        }

        // 5. Hand the authorized URL back to the caller.
        return url
    }
}
