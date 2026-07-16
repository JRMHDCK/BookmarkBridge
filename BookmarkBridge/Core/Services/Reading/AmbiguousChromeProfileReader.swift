//
//  AmbiguousChromeProfileReader.swift
//  BookmarkBridge
//

import Foundation

/// A reader for a Chrome profile that exposes **both** a `Bookmarks` and an
/// `AccountBookmarks` file.
///
/// V1 deliberately does not choose between them (no arbitrary priority), so this
/// reader surfaces the profile as `multipleBookmarkStores` rather than guessing.
/// The profile still appears in the dashboard, clearly flagged, until a
/// behaviour-based strategy is defined.
nonisolated struct AmbiguousChromeProfileReader: BookmarkReading {
    let source: BookmarkSource

    init(source: BookmarkSource) {
        self.source = source
    }

    func readBookmarkTree() async throws -> BookmarkTree {
        throw BookmarkError.multipleBookmarkStores(.chrome)
    }
}
