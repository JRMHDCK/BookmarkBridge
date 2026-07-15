//
//  TestDoubles.swift
//  BookmarkBridgeTests
//

import Foundation
@testable import BookmarkBridge

/// A `BookmarkReading` double that always fails, to exercise error paths.
struct FailingBookmarkReader: BookmarkReading {
    let source: BookmarkSource
    let error: BookmarkError

    init(browser: Browser, error: BookmarkError) {
        self.source = .singleProfile(browser)
        self.error = error
    }

    func readBookmarkTree() async throws -> BookmarkTree {
        throw error
    }
}

/// A `BrowserSourceProviding` double returning fixed readers, or throwing.
struct StubSourceProvider: BrowserSourceProviding {
    let browser: Browser
    let readers: [any BookmarkReading]
    let error: BookmarkError?

    init(browser: Browser, readers: [any BookmarkReading] = [], error: BookmarkError? = nil) {
        self.browser = browser
        self.readers = readers
        self.error = error
    }

    func makeReaders() async throws -> [BookmarkReading] {
        if let error { throw error }
        return readers
    }
}

/// A `BrowserSourceProviding` double that throws `authorizationRequired` until
/// its box is authorized, then returns fixed readers.
struct GatedSourceProvider: BrowserSourceProviding {
    let browser: Browser
    let box: AuthorizationBox
    let readers: [any BookmarkReading]

    func makeReaders() async throws -> [BookmarkReading] {
        guard box.isAuthorized else { throw BookmarkError.authorizationRequired(browser) }
        return readers
    }
}

/// A `BookmarkSourceLocating` double returning a preconfigured location or error.
struct StubBookmarkSourceLocator: BookmarkSourceLocating {
    let result: Result<BrowserLocation, BookmarkError>
    func locate(_ browser: Browser) throws -> BrowserLocation { try result.get() }
}

/// A shared authorization flag, so a gated reader and a fake requester can
/// coordinate in tests (authorize → the same reader then succeeds).
final class AuthorizationBox: @unchecked Sendable {
    var isAuthorized: Bool
    init(isAuthorized: Bool = false) { self.isAuthorized = isAuthorized }
}

/// A `BookmarkReading` double that throws `authorizationRequired` until its box
/// is authorized, then returns a fixed tree.
struct GatedBookmarkReader: BookmarkReading {
    let source: BookmarkSource
    let box: AuthorizationBox
    let tree: BookmarkTree

    init(browser: Browser, box: AuthorizationBox, tree: BookmarkTree) {
        self.source = .singleProfile(browser)
        self.box = box
        self.tree = tree
    }

    func readBookmarkTree() async throws -> BookmarkTree {
        guard box.isAuthorized else { throw BookmarkError.authorizationRequired(source.browser) }
        return tree
    }
}

/// A `BookmarkAuthorizationRequesting` double. On a granted outcome it flips the
/// shared box; a `false` outcome models user cancellation; a thrown error models
/// a genuine failure.
@MainActor
final class FakeAuthorizationRequester: BookmarkAuthorizationRequesting {
    let box: AuthorizationBox
    var outcome: Result<Bool, Error>
    private(set) var requestCount = 0

    init(box: AuthorizationBox, outcome: Result<Bool, Error>) {
        self.box = box
        self.outcome = outcome
    }

    func requestAuthorization(for browser: Browser) async throws -> Bool {
        requestCount += 1
        let granted = try outcome.get()
        if granted { box.isAuthorized = true }
        return granted
    }
}

/// A configurable `AccessAuthorizing` double — never opens a real NSOpenPanel.
/// Returns a URL or throws (e.g. `AccessError.cancelled`).
@MainActor
final class FakeAccessAuthorizer: AccessAuthorizing {
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
