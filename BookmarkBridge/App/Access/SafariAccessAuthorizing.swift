//
//  SafariAccessAuthorizing.swift
//  BookmarkBridge
//

import Foundation

/// Requests the user's permission to access Safari's bookmark file.
///
/// UI seam: the concrete implementation presents an `NSOpenPanel`. It returns
/// the URL the user selected, or throws `SafariAccessError.cancelled` if the
/// user cancels. It performs **no validation, persistence, or file reading** —
/// those belong to `SafariAccessCoordinator`.
@MainActor
protocol SafariAccessAuthorizing {
    func requestAccess() async throws -> URL
}

/// Errors produced while obtaining Safari access authorization.
nonisolated enum SafariAccessError: Error, Equatable, Sendable {
    /// The user dismissed the authorization UI without choosing a file.
    case cancelled
    /// The user selected a file that is not the expected Safari bookmarks file.
    case wrongFile(selected: URL)
    /// A security-scoped bookmark could not be created for the selected file.
    case bookmarkCreationFailed
    /// The created bookmark could not be persisted.
    case persistenceFailed
}
