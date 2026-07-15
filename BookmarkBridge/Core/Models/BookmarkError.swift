//
//  BookmarkError.swift
//  BookmarkBridge
//

import Foundation

/// Errors surfaced by the bookmark domain.
///
/// Typed and exhaustive so callers can react precisely and the UI can present
/// actionable messages. Domain code never uses `try!` or `fatalError` on these
/// paths.
nonisolated enum BookmarkError: Error, Sendable, Equatable {
    /// The browser's bookmark file could not be found at the expected location.
    case sourceNotFound(Browser)

    /// The sandbox denied access to the browser's bookmark file.
    case accessDenied(BrowserLocation)

    /// The bookmark data could not be decoded into a tree.
    case decodingFailed(Browser, reason: String)

    /// A referenced bookmark or folder id does not exist in the tree.
    case unknownNode(BookmarkID)

    /// The requested browser is not supported by this build.
    case unsupportedBrowser(Browser)
}
