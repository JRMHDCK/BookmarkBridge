//
//  Bookmark.swift
//  BookmarkBridge
//

import Foundation

/// A single bookmark entry: a titled link to a URL.
///
/// Immutable value type — reading a browser produces these; nothing mutates
/// them in place.
nonisolated struct Bookmark: Identifiable, Hashable, Sendable, Codable {
    let id: BookmarkID
    let title: String
    let url: URL
    let dateAdded: Date?

    init(id: BookmarkID, title: String, url: URL, dateAdded: Date? = nil) {
        self.id = id
        self.title = title
        self.url = url
        self.dateAdded = dateAdded
    }
}
