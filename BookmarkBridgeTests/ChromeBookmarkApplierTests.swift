//
//  ChromeBookmarkApplierTests.swift
//  BookmarkBridgeTests
//
//  Temporary files only — never a real Chrome profile.
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("ChromeBookmarkApplier")
struct ChromeBookmarkApplierTests {

    private struct StubDetector: RunningBrowserDetecting {
        let running: Set<Browser>
        func isRunning(_ browser: Browser) -> Bool { running.contains(browser) }
    }

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ApplierTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Writes the Chrome fixture to a temp "Bookmarks" file and returns the pieces.
    private func makeFixture() throws -> (location: BrowserLocation, backup: FileBookmarkBackup, profileDir: URL) {
        let profileDir = tempDir()
        let bookmarksURL = profileDir.appendingPathComponent("Bookmarks", isDirectory: false)
        try ChromeBookmarksFixture.data().write(to: bookmarksURL)
        return (
            BrowserLocation(browser: .chrome, fileURL: bookmarksURL),
            FileBookmarkBackup(rootDirectory: tempDir()),
            profileDir
        )
    }

    private func newBookmark() -> Bookmark {
        Bookmark(id: BookmarkID("n"), title: "New Site", url: URL(string: "https://new.example/")!)
    }

    @Test("Refuses to write while Chrome is running, leaving the file untouched")
    func refusesWhenChromeRunning() async throws {
        let f = try makeFixture()
        let applier = ChromeBookmarkApplier(detector: StubDetector(running: [.chrome]), backup: f.backup)
        let before = try Data(contentsOf: f.location.fileURL)

        await #expect(throws: ChromeWriteError.browserIsRunning) {
            try await applier.apply([newBookmark()], to: f.location, now: now)
        }
        #expect(try Data(contentsOf: f.location.fileURL) == before)   // unchanged
    }

    @Test("Backs up first, then writes the addition and a .bak")
    func writesAndBacksUp() async throws {
        let f = try makeFixture()
        let applier = ChromeBookmarkApplier(detector: StubDetector(running: []), backup: f.backup)
        let original = try Data(contentsOf: f.location.fileURL)

        let handle = try await applier.apply([newBookmark()], to: f.location, now: now)

        // The addition landed.
        let tree = try ChromeBookmarkDecoder().decodeTree(from: Data(contentsOf: f.location.fileURL))
        #expect(tree.allBookmarks.contains { $0.title == "New Site" })

        // The backup holds the pre-write bytes.
        #expect(FileManager.default.fileExists(atPath: handle.fileURL.path))
        #expect(try Data(contentsOf: handle.fileURL) == original)

        // Bookmarks.bak holds the pre-write bytes too.
        let bakURL = f.profileDir.appendingPathComponent("Bookmarks.bak", isDirectory: false)
        #expect(try Data(contentsOf: bakURL) == original)
    }

    @Test("Refuses to write a synced account bookmarks file (V1 read-only)")
    func refusesAccountBookmarks() async throws {
        let profileDir = tempDir()
        let accountURL = profileDir.appendingPathComponent("AccountBookmarks", isDirectory: false)
        try ChromeBookmarksFixture.data().write(to: accountURL)
        let location = BrowserLocation(browser: .chrome, fileURL: accountURL)
        let applier = ChromeBookmarkApplier(detector: StubDetector(running: []), backup: FileBookmarkBackup(rootDirectory: tempDir()))
        let before = try Data(contentsOf: accountURL)

        await #expect(throws: ChromeWriteError.accountBookmarksAreReadOnly) {
            try await applier.apply([newBookmark()], to: location, now: now)
        }
        #expect(try Data(contentsOf: accountURL) == before)   // untouched
    }

    @Test("The write is reversible via the returned backup handle")
    func writeIsReversible() async throws {
        let f = try makeFixture()
        let applier = ChromeBookmarkApplier(detector: StubDetector(running: []), backup: f.backup)
        let original = try Data(contentsOf: f.location.fileURL)

        let handle = try await applier.apply([newBookmark()], to: f.location, now: now)
        #expect(try Data(contentsOf: f.location.fileURL) != original)   // changed

        try await f.backup.restore(handle)
        #expect(try Data(contentsOf: f.location.fileURL) == original)   // fully restored
    }
}
