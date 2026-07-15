//
//  SafariBookmarkSourceLocator.swift
//  BookmarkBridge
//

import Foundation

/// Locates Safari's bookmark file: `~/Library/Safari/Bookmarks.plist`.
///
/// Single responsibility: compute *where* the file is. It performs **no I/O** —
/// it neither opens nor checks the file. Verifying existence and obtaining
/// sandbox permission are handled downstream by `FileAccessProviding`; decoding
/// is handled by `BookmarkDecoding`.
///
/// The home directory is injectable so tests never depend on the real account.
nonisolated struct SafariBookmarkSourceLocator: BookmarkSourceLocating {
    private let homeDirectory: URL

    init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.homeDirectory = homeDirectory
    }

    func locate(_ browser: Browser) throws -> BrowserLocation {
        guard browser == .safari else {
            throw BookmarkError.unsupportedBrowser(browser)
        }
        let fileURL = homeDirectory
            .appending(path: "Library", directoryHint: .isDirectory)
            .appending(path: "Safari", directoryHint: .isDirectory)
            .appending(path: "Bookmarks.plist", directoryHint: .notDirectory)
        return BrowserLocation(browser: .safari, fileURL: fileURL)
    }
}
