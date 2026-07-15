//
//  FileAccessProviding.swift
//  BookmarkBridge
//

import Foundation

/// Grants **read-only**, sandbox-scoped access to a browser's bookmark file.
///
/// The app runs in the App Sandbox with read-only user-selected file access
/// (`ENABLE_USER_SELECTED_FILES = readonly`). This protocol fully encapsulates
/// security-scoped resource handling: the caller receives a URL it is permitted
/// to read for the duration of `body`, and the scope is **always released**
/// before the call returns — including when `body` throws — so access can never
/// leak.
///
/// The API is deliberately Safari-agnostic and exposes no way to write.
nonisolated protocol FileAccessProviding: Sendable {
    /// Runs `body` while holding read-only access to `location`'s file and
    /// returns its result. Access is released before returning in all paths.
    func withReadOnlyAccess<T>(
        to location: BrowserLocation,
        _ body: (URL) throws -> T
    ) throws -> T
}
