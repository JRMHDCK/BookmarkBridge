//
//  BookmarkFolder.swift
//  BookmarkBridge
//

import Foundation

/// A named folder containing an ordered list of bookmarks and sub-folders.
nonisolated struct BookmarkFolder: Identifiable, Hashable, Sendable, Codable {
    let id: BookmarkID
    let title: String
    let children: [BookmarkNode]
    let dateAdded: Date?

    init(id: BookmarkID, title: String, children: [BookmarkNode] = [], dateAdded: Date? = nil) {
        self.id = id
        self.title = title
        self.children = children
        self.dateAdded = dateAdded
    }

    /// Every bookmark contained in this folder and its sub-folders, depth-first.
    /// Pure traversal — no I/O, no mutation.
    var allBookmarks: [Bookmark] {
        children.flatMap { node in
            switch node {
            case .bookmark(let bookmark): [bookmark]
            case .folder(let folder): folder.allBookmarks
            }
        }
    }
}
