//
//  FolderTitleFormatter.swift
//  BookmarkBridge
//

import Foundation

/// Maps browsers' technical root folder names to human-readable French names.
///
/// Shared across features (the explorer and global search) so a folder always
/// reads the same way wherever it appears. Any other title is returned
/// unchanged.
nonisolated enum FolderTitleFormatter {
    static func friendly(_ rawTitle: String) -> String {
        switch rawTitle {
        case "BookmarksBar": "Barre des favoris"
        case "BookmarksMenu": "Autres favoris"
        case "com.apple.ReadingList": "Liste de lecture"
        default: rawTitle
        }
    }
}
