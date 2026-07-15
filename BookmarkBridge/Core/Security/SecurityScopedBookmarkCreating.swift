//
//  SecurityScopedBookmarkCreating.swift
//  BookmarkBridge
//

import Foundation

/// Creates an app-scoped, **read-only** security-scoped bookmark for a URL that
/// the user has granted access to (e.g. via `NSOpenPanel`).
///
/// Single responsibility: turn an authorized URL into persistable bookmark
/// `Data`. It stores nothing and resolves nothing.
nonisolated protocol SecurityScopedBookmarkCreating: Sendable {
    func makeBookmark(for url: URL) throws -> Data
}

/// Production implementation over Foundation's bookmark API.
///
/// Uses `.withSecurityScope` + `.securityScopeAllowOnlyReadAccess`, so the
/// resulting bookmark can only ever be resolved for read access — consistent
/// with the project's read-only principle. Its success path requires a
/// user-granted URL, so it is exercised via manual/integration testing rather
/// than unit tests.
nonisolated struct SystemSecurityScopedBookmarkCreator: SecurityScopedBookmarkCreating {
    init() {}

    func makeBookmark(for url: URL) throws -> Data {
        try url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }
}
