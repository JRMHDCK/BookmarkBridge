//
//  TestDoubles.swift
//  BookmarkBridgeTests
//

import Foundation
@testable import BookmarkBridge

/// A `BookmarkReading` double that always fails, to exercise error paths.
struct FailingBookmarkReader: BookmarkReading {
    let browser: Browser
    let error: BookmarkError

    init(browser: Browser, error: BookmarkError) {
        self.browser = browser
        self.error = error
    }

    func readBookmarkTree() async throws -> BookmarkTree {
        throw error
    }
}
