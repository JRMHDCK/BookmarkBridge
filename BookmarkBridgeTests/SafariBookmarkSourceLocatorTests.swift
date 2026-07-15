//
//  SafariBookmarkSourceLocatorTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("SafariBookmarkSourceLocator")
struct SafariBookmarkSourceLocatorTests {

    @Test("Locates Bookmarks.plist under Library/Safari of the given home")
    func locatesSafariFile() throws {
        let home = URL(fileURLWithPath: "/Users/tester", isDirectory: true)
        let locator = SafariBookmarkSourceLocator(homeDirectory: home)

        let location = try locator.locate(.safari)

        #expect(location.browser == .safari)
        #expect(location.fileURL.path(percentEncoded: false) == "/Users/tester/Library/Safari/Bookmarks.plist")
    }

    @Test("Rejects non-Safari browsers")
    func rejectsOtherBrowsers() {
        let locator = SafariBookmarkSourceLocator(
            homeDirectory: URL(fileURLWithPath: "/Users/tester", isDirectory: true)
        )

        #expect(throws: BookmarkError.unsupportedBrowser(.chrome)) {
            try locator.locate(.chrome)
        }
    }

    @Test("Does not touch the filesystem (pure path computation)")
    func performsNoIO() throws {
        // A home that does not exist must still yield a location, proving locate()
        // computes a path without reading the disk.
        let home = URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)", isDirectory: true)
        let locator = SafariBookmarkSourceLocator(homeDirectory: home)

        let location = try locator.locate(.safari)

        #expect(location.fileURL.lastPathComponent == "Bookmarks.plist")
    }
}
