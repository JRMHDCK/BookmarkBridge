//
//  ChromeSourceProviderTests.swift
//  BookmarkBridgeTests
//
//  Exercises Chrome discovery + per-profile reading against a temporary Chrome
//  directory built from fixtures. Never touches real Chrome data.
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("ChromeSourceProvider & ChromeBookmarkReader")
struct ChromeSourceProviderTests {

    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    /// Builds a temporary Chrome directory with two profiles and (optionally)
    /// a Local State file. Returns the Chrome directory.
    private func makeChromeDirectory(includeLocalState: Bool) throws -> URL {
        let fileManager = FileManager.default
        let base = fileManager.temporaryDirectory
            .appending(path: "bb-chrome-\(UUID().uuidString)", directoryHint: .isDirectory)
        let chrome = base.appending(path: "Chrome", directoryHint: .isDirectory)

        let defaultDir = chrome.appending(path: "Default", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: defaultDir, withIntermediateDirectories: true)
        try ChromeBookmarksFixture.data().write(to: defaultDir.appending(path: "Bookmarks", directoryHint: .notDirectory))

        let profile1Dir = chrome.appending(path: "Profile 1", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: profile1Dir, withIntermediateDirectories: true)
        try ChromeBookmarksFixture.data(includeSyncedItem: true)
            .write(to: profile1Dir.appending(path: "Bookmarks", directoryHint: .notDirectory))

        if includeLocalState {
            try ChromeLocalStateFixture.data()
                .write(to: chrome.appending(path: "Local State", directoryHint: .notDirectory))
        }
        return chrome
    }

    private func remove(_ chromeDirectory: URL) {
        try? FileManager.default.removeItem(at: chromeDirectory.deletingLastPathComponent())
    }

    private func makeProvider(chromeDirectory: URL) -> ChromeSourceProvider {
        ChromeSourceProvider(
            directoryLocator: StubBookmarkSourceLocator(
                result: .success(BrowserLocation(browser: .chrome, fileURL: chromeDirectory))
            ),
            fileAccess: SandboxFileAccessProvider(),
            profileLocator: DefaultChromeProfileLocator(),
            decoder: ChromeBookmarkDecoder(),
            now: { self.fixedDate }
        )
    }

    // MARK: - Discovery

    @Test("Discovers one reader per profile, named from Local State")
    func discoversProfilesWithNames() async throws {
        let chrome = try makeChromeDirectory(includeLocalState: true)
        defer { remove(chrome) }

        let readers = try await makeProvider(chromeDirectory: chrome).makeReaders()

        #expect(readers.map(\.source.displayName) == ["Chrome — Personnel", "Chrome — Travail"])
        #expect(readers.map(\.source.id.profile) == ["Default", "Profile 1"])
    }

    @Test("Falls back to the directory name when Local State is absent")
    func fallsBackToDirectoryName() async throws {
        let chrome = try makeChromeDirectory(includeLocalState: false)
        defer { remove(chrome) }

        let readers = try await makeProvider(chromeDirectory: chrome).makeReaders()

        #expect(readers.map(\.source.displayName) == ["Chrome — Default", "Chrome — Profile 1"])
    }

    // MARK: - Reading (no mixing between profiles)

    @Test("Each reader reads its own profile without mixing bookmarks")
    func readsEachProfileIndependently() async throws {
        let chrome = try makeChromeDirectory(includeLocalState: true)
        defer { remove(chrome) }

        let readers = try await makeProvider(chromeDirectory: chrome).makeReaders()

        let defaultTree = try await readers[0].readBookmarkTree()
        let profile1Tree = try await readers[1].readBookmarkTree()

        #expect(defaultTree.browser == .chrome)
        #expect(defaultTree.bookmarkCount == 6)          // synced empty
        #expect(profile1Tree.bookmarkCount == 7)         // synced item included
        #expect(defaultTree.capturedAt == fixedDate)
    }

    // MARK: - Ambiguous storage

    @Test("A profile with both bookmark files is surfaced as multiple-stores, not auto-picked")
    func flagsProfileWithBothStores() async throws {
        let fileManager = FileManager.default
        let base = fileManager.temporaryDirectory
            .appending(path: "bb-chrome-\(UUID().uuidString)", directoryHint: .isDirectory)
        let chrome = base.appending(path: "Chrome", directoryHint: .isDirectory)
        defer { try? fileManager.removeItem(at: base) }

        let bothDir = chrome.appending(path: "Profile 2", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: bothDir, withIntermediateDirectories: true)
        try ChromeBookmarksFixture.data().write(to: bothDir.appending(path: "Bookmarks", directoryHint: .notDirectory))
        try ChromeBookmarksFixture.data().write(to: bothDir.appending(path: "AccountBookmarks", directoryHint: .notDirectory))

        let readers = try await makeProvider(chromeDirectory: chrome).makeReaders()
        #expect(readers.count == 1)
        await #expect(throws: BookmarkError.multipleBookmarkStores(.chrome)) {
            _ = try await readers[0].readBookmarkTree()
        }
    }

    // MARK: - Authorization

    @Test("Propagates authorizationRequired when the directory is not authorized")
    func propagatesAuthorizationRequired() async {
        let provider = ChromeSourceProvider(
            directoryLocator: StubBookmarkSourceLocator(result: .failure(.authorizationRequired(.chrome)))
        )

        await #expect(throws: BookmarkError.authorizationRequired(.chrome)) {
            _ = try await provider.makeReaders()
        }
    }
}
