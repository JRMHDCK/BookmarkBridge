//
//  BookmarkReading.swift
//  BookmarkBridge
//

import Foundation

/// Reads a single browser's bookmarks into an immutable `BookmarkTree`.
///
/// This is the *only* capability required by the phase-1 (read-only) pipeline.
/// Implementations live per browser (e.g. Safari, Chrome) and are injected at
/// the composition root; the domain never depends on a concrete reader.
nonisolated protocol BookmarkReading: Sendable {
    /// The browser this reader understands.
    var browser: Browser { get }

    /// Reads and decodes the current bookmarks.
    /// Read-only: implementations must never mutate the source.
    func readBookmarkTree() async throws -> BookmarkTree
}
