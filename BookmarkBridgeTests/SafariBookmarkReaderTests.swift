//
//  SafariBookmarkReaderTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

// MARK: - Local doubles

/// A locator that returns a preconfigured location or error.
private struct StubSourceLocator: BookmarkSourceLocating {
    let result: Result<BrowserLocation, BookmarkError>
    func locate(_ browser: Browser) throws -> BrowserLocation { try result.get() }
}

/// Records which URLs it was asked to read, and returns a preconfigured result.
private final class RecordingDataReader: @unchecked Sendable {
    let result: Result<Data, Error>
    private(set) var readURLs: [URL] = []
    init(_ result: Result<Data, Error>) { self.result = result }
    func read(_ url: URL) throws -> Data {
        readURLs.append(url)
        return try result.get()
    }
}

private struct Boom: Error {}

@Suite("SafariBookmarkReader")
struct SafariBookmarkReaderTests {

    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func location(_ path: String) -> BrowserLocation {
        BrowserLocation(browser: .safari, fileURL: URL(fileURLWithPath: path))
    }

    // MARK: - Successful integration (temporary file only)

    @Test("Reads a full tree from a temporary file built from the fixture")
    func readsCompletelyFromTemporaryFile() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: "bb-safari-\(UUID().uuidString).plist")
        try SafariBookmarksFixture.data().write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let reader = SafariBookmarkReader(
            locator: StubSourceLocator(result: .success(BrowserLocation(browser: .safari, fileURL: fileURL))),
            fileAccess: SandboxFileAccessProvider(),
            decoder: SafariBookmarkDecoder(),
            now: { self.fixedDate }
        )

        let tree = try await reader.readBookmarkTree()

        #expect(tree.browser == .safari)
        #expect(tree.roots.count == 3)
        #expect(tree.bookmarkCount == 7)
        // capturedAt is stamped by the reader, not the decoder's sentinel.
        #expect(tree.capturedAt == fixedDate)
        #expect(tree.capturedAt != .distantPast)
    }

    // MARK: - Error propagation

    @Test("Propagates a location error and never attempts access")
    func propagatesLocationError() async {
        let spy = SpySecurityScopedFileController()
        let reader = SafariBookmarkReader(
            locator: StubSourceLocator(result: .failure(.sourceNotFound(.safari))),
            fileAccess: SandboxFileAccessProvider(controller: spy),
            readData: { _ in Data() },
            now: { self.fixedDate }
        )

        await #expect(throws: BookmarkError.sourceNotFound(.safari)) {
            try await reader.readBookmarkTree()
        }
        #expect(spy.startCount == 0)
        #expect(spy.stopCount == 0)
    }

    @Test("Propagates an access denial and still releases access")
    func propagatesAccessDenied() async {
        let spy = SpySecurityScopedFileController()
        spy.readable = false
        let loc = location("/tmp/denied.plist")
        let reader = SafariBookmarkReader(
            locator: StubSourceLocator(result: .success(loc)),
            fileAccess: SandboxFileAccessProvider(controller: spy),
            readData: { _ in Data() },
            now: { self.fixedDate }
        )

        await #expect(throws: BookmarkError.accessDenied(loc)) {
            try await reader.readBookmarkTree()
        }
        #expect(spy.stopCount == 1)
    }

    @Test("Propagates a read error and still releases access")
    func propagatesReadError() async {
        let spy = SpySecurityScopedFileController()
        let reader = SafariBookmarkReader(
            locator: StubSourceLocator(result: .success(location("/tmp/x.plist"))),
            fileAccess: SandboxFileAccessProvider(controller: spy),
            readData: { _ in throw Boom() },
            now: { self.fixedDate }
        )

        await #expect(throws: Boom.self) {
            try await reader.readBookmarkTree()
        }
        #expect(spy.startCount == 1)
        #expect(spy.stopCount == 1)
    }

    @Test("Propagates a decoding error (access already released before decoding)")
    func propagatesDecodingError() async {
        let spy = SpySecurityScopedFileController()
        let reader = SafariBookmarkReader(
            locator: StubSourceLocator(result: .success(location("/tmp/x.plist"))),
            fileAccess: SandboxFileAccessProvider(controller: spy),
            decoder: SafariBookmarkDecoder(),
            readData: { _ in Data("not a property list".utf8) },
            now: { self.fixedDate }
        )

        await #expect(throws: BookmarkError.self) {
            try await reader.readBookmarkTree()
        }
        #expect(spy.stopCount == 1)
    }

    // MARK: - Resource closing & capture time

    @Test("Releases access after a successful read")
    func closesAccessOnSuccess() async throws {
        let spy = SpySecurityScopedFileController()
        let reader = SafariBookmarkReader(
            locator: StubSourceLocator(result: .success(location("/tmp/ok.plist"))),
            fileAccess: SandboxFileAccessProvider(controller: spy),
            decoder: SafariBookmarkDecoder(),
            readData: { _ in try SafariBookmarksFixture.data() },
            now: { self.fixedDate }
        )

        let tree = try await reader.readBookmarkTree()

        #expect(tree.capturedAt == fixedDate)
        #expect(spy.startCount == 1)
        #expect(spy.stopCount == 1)
    }

    // MARK: - Never touches the real Safari file

    @Test("Reads only the located path, never the real Safari file")
    func readsOnlyLocatedPath() async throws {
        let temporaryPath = "/tmp/bb-located-\(UUID().uuidString).plist"
        let recorder = RecordingDataReader(.success(try SafariBookmarksFixture.data()))
        let reader = SafariBookmarkReader(
            locator: StubSourceLocator(result: .success(location(temporaryPath))),
            fileAccess: SandboxFileAccessProvider(controller: SpySecurityScopedFileController()),
            decoder: SafariBookmarkDecoder(),
            readData: { try recorder.read($0) },
            now: { self.fixedDate }
        )

        _ = try await reader.readBookmarkTree()

        #expect(recorder.readURLs.map { $0.path(percentEncoded: false) } == [temporaryPath])
        #expect(!recorder.readURLs.contains { $0.path(percentEncoded: false).contains("/Library/Safari/Bookmarks.plist") })
    }
}
