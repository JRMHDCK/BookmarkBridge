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

/// A configurable `SafariAccessAuthorizing` double — never opens a real
/// NSOpenPanel. Returns a URL or throws (e.g. `SafariAccessError.cancelled`).
@MainActor
final class FakeSafariAccessAuthorizer: SafariAccessAuthorizing {
    var result: Result<URL, Error>
    private(set) var requestCount = 0

    init(_ result: Result<URL, Error>) { self.result = result }

    func requestAccess() async throws -> URL {
        requestCount += 1
        return try result.get()
    }
}

/// An in-memory `BookmarkStore` double with configurable load/save failures,
/// for testing components that persist bookmarks without touching disk.
final class InMemoryBookmarkStore: BookmarkStore, @unchecked Sendable {
    private var storage: [Browser: Data] = [:]
    var loadError: Error?
    var saveError: Error?
    private(set) var saveCount = 0

    init() {}

    /// Preloads a stored bookmark (test setup).
    func preset(_ data: Data, for browser: Browser) { storage[browser] = data }

    func loadBookmark(for browser: Browser) throws -> Data? {
        if let loadError { throw loadError }
        return storage[browser]
    }

    func saveBookmark(_ bookmark: Data, for browser: Browser) throws {
        if let saveError { throw saveError }
        storage[browser] = bookmark
        saveCount += 1
    }

    func clearBookmark(for browser: Browser) throws {
        storage[browser] = nil
    }
}

/// A configurable `SecurityScopedBookmarkCreating` double that records the URLs
/// it was asked to bookmark.
final class StubBookmarkCreator: SecurityScopedBookmarkCreating, @unchecked Sendable {
    var result: Result<Data, Error>
    private(set) var requestedURLs: [URL] = []

    init(_ result: Result<Data, Error>) { self.result = result }

    func makeBookmark(for url: URL) throws -> Data {
        requestedURLs.append(url)
        return try result.get()
    }
}

/// A configurable `SecurityScopedBookmarkResolving` double that records the data
/// it was asked to resolve.
final class StubBookmarkResolver: SecurityScopedBookmarkResolving, @unchecked Sendable {
    var result: Result<ResolvedBookmark, Error>
    private(set) var resolvedData: [Data] = []

    init(_ result: Result<ResolvedBookmark, Error>) { self.result = result }

    func resolve(_ data: Data) throws -> ResolvedBookmark {
        resolvedData.append(data)
        return try result.get()
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
