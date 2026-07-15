//
//  AccessAuthorizing.swift
//  BookmarkBridge
//

import Foundation

/// Requests the user's permission to access a browser's bookmark file or folder.
///
/// UI seam: the concrete implementation presents an `NSOpenPanel` (a file for
/// Safari, a directory for Chrome). It returns the URL the user selected, or
/// throws `AccessError.cancelled` if the user cancels. It performs **no
/// validation, persistence, or file reading** — those belong to
/// `BrowserAccessCoordinator`.
@MainActor
protocol AccessAuthorizing {
    func requestAccess() async throws -> URL
}

/// Errors produced while obtaining access authorization.
nonisolated enum AccessError: Error, Equatable, Sendable {
    /// The user dismissed the authorization UI without choosing anything.
    case cancelled
    /// The user selected an item that is not the expected file/folder.
    case wrongFile(selected: URL)
    /// A security-scoped bookmark could not be created for the selection.
    case bookmarkCreationFailed
    /// The created bookmark could not be persisted.
    case persistenceFailed
}
