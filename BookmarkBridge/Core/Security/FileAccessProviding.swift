//
//  FileAccessProviding.swift
//  BookmarkBridge
//

import Foundation

/// Grants sandbox-scoped access to a browser's bookmark file.
///
/// The app runs in the App Sandbox with read-only user-selected file access
/// (`ENABLE_USER_SELECTED_FILES = readonly`). This protocol abstracts
/// security-scoped bookmark resolution so the rest of the app deals only in
/// `URL`s it is actually permitted to read.
///
/// Only read access is exposed while the project is in its read-only phase; a
/// write-access counterpart will be added alongside `BookmarkWriting` in phase 2.
nonisolated protocol FileAccessProviding: Sendable {
    /// Begins read-only access to `location`, returning a usable file URL.
    /// Callers must balance this with `endAccess(to:)`.
    func beginReadOnlyAccess(to location: BrowserLocation) async throws -> URL

    /// Ends access previously started for `location`.
    func endAccess(to location: BrowserLocation) async
}
