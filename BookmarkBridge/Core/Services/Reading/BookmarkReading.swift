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
    /// The source (browser + optional profile) this reader understands.
    var source: BookmarkSource { get }

    /// Reads and decodes the current bookmarks.
    /// Read-only: implementations must never mutate the source.
    func readBookmarkTree() async throws -> BookmarkTree

    /// The file this reader's bookmarks could be written back to, when V1
    /// supports writing it (a Chrome local `Bookmarks` file). `nil` when the
    /// source is read-only in V1 (Safari, account bookmarks, ambiguous profiles).
    var writableLocation: BrowserLocation? { get }
}

extension BookmarkReading {
    /// Read-only by default; only writable sources override this.
    nonisolated var writableLocation: BrowserLocation? { nil }
}
