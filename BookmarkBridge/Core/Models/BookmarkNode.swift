//
//  BookmarkNode.swift
//  BookmarkBridge
//

import Foundation

/// A node in a bookmark tree: either a bookmark or a folder.
///
/// The tree is an immutable value hierarchy; folders hold their children by
/// value, so an entire hierarchy can be compared, copied, and tested
/// deterministically.
nonisolated enum BookmarkNode: Hashable, Sendable, Codable, Identifiable {
    case bookmark(Bookmark)
    case folder(BookmarkFolder)

    var id: BookmarkID {
        switch self {
        case .bookmark(let bookmark): bookmark.id
        case .folder(let folder): folder.id
        }
    }

    /// The display title, whichever kind of node this is.
    var title: String {
        switch self {
        case .bookmark(let bookmark): bookmark.title
        case .folder(let folder): folder.title
        }
    }

    /// Whether this node is a folder.
    var isFolder: Bool {
        if case .folder = self { true } else { false }
    }
}
