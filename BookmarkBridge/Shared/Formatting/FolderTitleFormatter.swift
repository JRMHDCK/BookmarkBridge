//
//  FolderTitleFormatter.swift
//  BookmarkBridge
//

import Foundation

/// Maps browsers' technical root folder names to localized readable names.
///
/// Shared across features (the explorer and global search) so a folder always
/// reads the same way wherever it appears. Any other title is returned
/// unchanged.
enum FolderTitleFormatter {
    static func friendly(_ rawTitle: String) -> String {
        switch rawTitle {
        case "BookmarksBar": DocumentationText.value("folder.bookmarksBar")
        case "BookmarksMenu": DocumentationText.value("folder.bookmarksMenu")
        case "com.apple.ReadingList": DocumentationText.value("folder.readingList")
        default: rawTitle
        }
    }
}
