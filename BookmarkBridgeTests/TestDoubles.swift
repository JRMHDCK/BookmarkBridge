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

/// A spy controller for `SandboxFileAccessProvider`: configurable outcomes plus
/// start/stop counters, so tests can assert resource balancing without touching
/// the real filesystem or Safari.
final class SpySecurityScopedFileController: SecurityScopedFileControlling, @unchecked Sendable {
    var exists = true
    var readable = true
    var startReturnValue = true

    private(set) var startCount = 0
    private(set) var stopCount = 0

    func fileExists(at url: URL) -> Bool { exists }
    func isReadable(at url: URL) -> Bool { readable }
    func startAccessing(_ url: URL) -> Bool {
        startCount += 1
        return startReturnValue
    }
    func stopAccessing(_ url: URL) {
        stopCount += 1
    }
}
