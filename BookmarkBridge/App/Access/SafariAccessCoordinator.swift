//
//  SafariAccessCoordinator.swift
//  BookmarkBridge
//

import Foundation

/// Coordinates the one-time Safari access authorization flow.
///
/// It **only** authorizes; it never decodes favourites, opens or reads the file,
/// builds a `BookmarkTree`, parses anything, or depends on the Safari reader. Its
/// single job is: obtain permission, validate the selected file, create a
/// read-only security-scoped bookmark, persist it, and return the authorized URL.
///
/// Steps of `authorize()`:
/// 1. ask `SafariAccessAuthorizing` for a file (propagates `.cancelled`);
/// 2. validate the selection is the expected Safari bookmarks file;
/// 3. create a read-only security-scoped bookmark;
/// 4. persist it via `BookmarkStore`;
/// 5. return the authorized URL to the caller (which triggers a reload).
@MainActor
struct SafariAccessCoordinator {
    /// Expected trailing path of the Safari bookmarks file. Validated as a
    /// suffix because the real file lives under the user's true home, not the
    /// sandbox container.
    static let expectedPathSuffix = "Library/Safari/Bookmarks.plist"

    private let authorizer: any SafariAccessAuthorizing
    private let creator: SecurityScopedBookmarkCreating
    private let store: BookmarkStore
    private let expectedPathSuffix: String

    init(
        authorizer: any SafariAccessAuthorizing,
        creator: SecurityScopedBookmarkCreating,
        store: BookmarkStore,
        expectedPathSuffix: String = SafariAccessCoordinator.expectedPathSuffix
    ) {
        self.authorizer = authorizer
        self.creator = creator
        self.store = store
        self.expectedPathSuffix = expectedPathSuffix
    }

    @discardableResult
    func authorize() async throws -> URL {
        // 1. Ask the user (cancellation propagates as SafariAccessError.cancelled).
        let url = try await authorizer.requestAccess()

        // 2. Never silently accept the wrong file.
        guard url.path(percentEncoded: false).hasSuffix(expectedPathSuffix) else {
            throw SafariAccessError.wrongFile(selected: url)
        }

        // 3. Create a read-only security-scoped bookmark.
        let bookmark: Data
        do {
            bookmark = try creator.makeBookmark(for: url)
        } catch {
            throw SafariAccessError.bookmarkCreationFailed
        }

        // 4. Persist it.
        do {
            try store.saveBookmark(bookmark, for: .safari)
        } catch {
            throw SafariAccessError.persistenceFailed
        }

        // 5. Hand the authorized URL back to the caller.
        return url
    }
}
