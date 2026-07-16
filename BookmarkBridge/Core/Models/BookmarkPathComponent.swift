//
//  BookmarkPathComponent.swift
//  BookmarkBridge
//

import Foundation

/// One ancestor folder on the way to a node, kept lightweight (id + title) so it
/// can be carried by value without a whole sub-tree.
///
/// Shared across the domain: search results use it to describe a hit's location,
/// and sync changes use it to record a bookmark's **origin folder path** so the
/// folder structure can be reconstructed at write time. Ids are resolved against
/// the in-memory tree; raw titles are mapped to friendly names for display.
nonisolated struct BookmarkPathComponent: Hashable, Sendable {
    let id: BookmarkID
    let title: String

    init(id: BookmarkID, title: String) {
        self.id = id
        self.title = title
    }
}
