//
//  DefaultChromeProfileLocatorTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("DefaultChromeProfileLocator")
struct DefaultChromeProfileLocatorTests {

    /// Builds a temporary Chrome directory with a few profile subdirectories.
    /// Returns the Chrome directory; caller removes its parent to clean up.
    private func makeChromeDirectory() throws -> URL {
        let fileManager = FileManager.default
        let base = fileManager.temporaryDirectory
            .appending(path: "bb-chrome-\(UUID().uuidString)", directoryHint: .isDirectory)
        let chrome = base.appending(path: "Chrome", directoryHint: .isDirectory)

        // Real profiles (each with a Bookmarks file).
        for profile in ["Default", "Profile 1"] {
            let directory = chrome.appending(path: profile, directoryHint: .isDirectory)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data().write(to: directory.appending(path: "Bookmarks", directoryHint: .notDirectory))
        }
        // Excluded by name, even though it has a Bookmarks file.
        let system = chrome.appending(path: "System Profile", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: system, withIntermediateDirectories: true)
        try Data().write(to: system.appending(path: "Bookmarks", directoryHint: .notDirectory))
        // Excluded: a directory without a Bookmarks file.
        try fileManager.createDirectory(
            at: chrome.appending(path: "NotAProfile", directoryHint: .isDirectory),
            withIntermediateDirectories: true
        )
        // Local State file (not a profile).
        try Data().write(to: chrome.appending(path: "Local State", directoryHint: .notDirectory))

        return chrome
    }

    private func remove(_ chromeDirectory: URL) {
        try? FileManager.default.removeItem(at: chromeDirectory.deletingLastPathComponent())
    }

    // MARK: - Path computation (pure)

    @Test("Computes the default Chrome directory from the home directory")
    func computesDefaultChromeDirectory() {
        let locator = DefaultChromeProfileLocator(
            homeDirectory: URL(fileURLWithPath: "/Users/tester", isDirectory: true)
        )
        var path = locator.defaultChromeDirectory().path(percentEncoded: false)
        if path.hasSuffix("/") { path.removeLast() }
        #expect(path == "/Users/tester/Library/Application Support/Google/Chrome")
    }

    @Test("Computes the Local State URL inside a Chrome directory")
    func computesLocalStateURL() {
        let locator = DefaultChromeProfileLocator()
        let chrome = URL(fileURLWithPath: "/tmp/Chrome", isDirectory: true)
        #expect(locator.localStateURL(in: chrome).lastPathComponent == "Local State")
    }

    // MARK: - Enumeration

    @Test("Enumerates only profile directories that contain a Bookmarks file")
    func enumeratesProfiles() throws {
        let chrome = try makeChromeDirectory()
        defer { remove(chrome) }

        let profiles = try DefaultChromeProfileLocator().profiles(in: chrome)

        #expect(profiles.map(\.profileDirectoryName) == ["Default", "Profile 1"])
        #expect(profiles.allSatisfy { $0.bookmarksURL.lastPathComponent == "Bookmarks" })
    }

    @Test("Throws sourceNotFound when the Chrome directory is missing")
    func throwsWhenMissing() {
        let missing = FileManager.default.temporaryDirectory
            .appending(path: "bb-missing-\(UUID().uuidString)", directoryHint: .isDirectory)
        #expect(throws: BookmarkError.sourceNotFound(.chrome)) {
            _ = try DefaultChromeProfileLocator().profiles(in: missing)
        }
    }
}
