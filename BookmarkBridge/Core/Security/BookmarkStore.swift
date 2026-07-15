//
//  BookmarkStore.swift
//  BookmarkBridge
//

import Foundation

/// Persists an opaque security-scoped bookmark blob per browser.
///
/// Single responsibility: **storage of `Data` only**. It never interprets the
/// bookmark, never resolves it to a URL, and never stores bookmark *content*
/// (the favourites themselves). It has no dependency on any UI framework.
nonisolated protocol BookmarkStore: Sendable {
    /// Returns the stored bookmark for `browser`, or `nil` if none exists.
    /// Throws `BookmarkStoreError` when stored data is present but unreadable.
    func loadBookmark(for browser: Browser) throws -> Data?

    /// Atomically stores `bookmark` for `browser`, replacing any previous value.
    func saveBookmark(_ bookmark: Data, for browser: Browser) throws

    /// Removes any stored bookmark for `browser`. A no-op if none exists.
    func clearBookmark(for browser: Browser) throws
}

/// Errors raised while reading a persisted bookmark.
nonisolated enum BookmarkStoreError: Error, Equatable {
    /// The stored file exists but could not be parsed.
    case corruptedData
    /// The stored file uses an unsupported format version.
    case unsupportedVersion(Int)
}
