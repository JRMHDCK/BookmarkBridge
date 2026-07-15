//
//  BookmarkSourceLocating.swift
//  BookmarkBridge
//

import Foundation

/// Resolves where a browser keeps its bookmark file.
///
/// Separated from `BookmarkReading` (Interface Segregation) so that locating a
/// source and reading it can evolve and be tested independently.
nonisolated protocol BookmarkSourceLocating: Sendable {
    /// Returns the on-disk location of the given browser's bookmarks.
    func locate(_ browser: Browser) throws -> BrowserLocation
}
