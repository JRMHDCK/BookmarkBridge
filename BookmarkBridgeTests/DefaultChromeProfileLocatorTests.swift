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
        let allLocal = profiles.allSatisfy { if case .bookmarks = $0.storage { true } else { false } }
        #expect(allLocal)
    }

    @Test("Discovers account-only profiles and flags ambiguity when both files exist")
    func discoversAccountBookmarks() throws {
        let fileManager = FileManager.default
        let base = fileManager.temporaryDirectory
            .appending(path: "bb-account-\(UUID().uuidString)", directoryHint: .isDirectory)
        let chrome = base.appending(path: "Chrome", directoryHint: .isDirectory)
        defer { try? fileManager.removeItem(at: base) }

        // Signed-in profile: only AccountBookmarks.
        let accountOnly = chrome.appending(path: "Profile 2", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: accountOnly, withIntermediateDirectories: true)
        try Data().write(to: accountOnly.appending(path: "AccountBookmarks", directoryHint: .notDirectory))

        // Profile with both: local should win.
        let both = chrome.appending(path: "Profile 3", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: both, withIntermediateDirectories: true)
        try Data().write(to: both.appending(path: "Bookmarks", directoryHint: .notDirectory))
        try Data().write(to: both.appending(path: "AccountBookmarks", directoryHint: .notDirectory))

        let profiles = try DefaultChromeProfileLocator().profiles(in: chrome)

        #expect(profiles.map(\.profileDirectoryName) == ["Profile 2", "Profile 3"])

        // Account-only profile → .account (the AccountBookmarks file).
        if case .account(let url) = profiles.first(where: { $0.profileDirectoryName == "Profile 2" })?.storage {
            #expect(url.lastPathComponent == "AccountBookmarks")
        } else {
            Issue.record("expected Profile 2 to use the account storage")
        }

        // Both files present → .ambiguous (no arbitrary pick).
        if case .ambiguous(let bookmarks, let account) = profiles.first(where: { $0.profileDirectoryName == "Profile 3" })?.storage {
            #expect(bookmarks.lastPathComponent == "Bookmarks")
            #expect(account.lastPathComponent == "AccountBookmarks")
        } else {
            Issue.record("expected Profile 3 to be ambiguous (both files)")
        }
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
