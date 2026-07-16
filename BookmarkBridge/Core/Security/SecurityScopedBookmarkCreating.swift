//
//  SecurityScopedBookmarkCreating.swift
//  BookmarkBridge
//

import Foundation

/// Creates an app-scoped security-scoped bookmark for a URL that the user has
/// granted access to (e.g. via `NSOpenPanel`).
///
/// Single responsibility: turn an authorized URL into persistable bookmark
/// `Data`. It stores nothing and resolves nothing.
nonisolated protocol SecurityScopedBookmarkCreating: Sendable {
    func makeBookmark(for url: URL) throws -> Data
}

/// Production implementation over Foundation's bookmark API.
///
/// Uses `.withSecurityScope` (read-write). Reading remains the default use, but
/// V1 sync also writes the Chrome `Bookmarks` file back through the same
/// bookmark, which requires write access — hence no `securityScopeAllowOnlyReadAccess`.
/// Its success path requires a user-granted URL, so it is exercised via
/// manual/integration testing rather than unit tests.
nonisolated struct SystemSecurityScopedBookmarkCreator: SecurityScopedBookmarkCreating {
    init() {}

    func makeBookmark(for url: URL) throws -> Data {
        try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }
}
