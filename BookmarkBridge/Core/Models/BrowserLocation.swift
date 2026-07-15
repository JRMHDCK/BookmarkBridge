//
//  BrowserLocation.swift
//  BookmarkBridge
//

import Foundation

/// Where a browser stores its bookmarks on disk.
///
/// Plain data that names the file to read. Obtaining sandbox permission to
/// actually read it is the concern of `FileAccessProviding` (Core/Security),
/// keeping location and authorization separate.
nonisolated struct BrowserLocation: Hashable, Sendable, Codable {
    let browser: Browser
    let fileURL: URL

    init(browser: Browser, fileURL: URL) {
        self.browser = browser
        self.fileURL = fileURL
    }
}
