//
//  OpenPanelSafariAccessAuthorizerTests.swift
//  BookmarkBridgeTests
//
//  These tests exercise the authorizer's mapping logic (selection → URL,
//  cancellation, wrong file) by injecting the panel outcome. The real
//  NSOpenPanel presentation requires a GUI session and is intentionally NOT
//  unit-tested here (it cannot run headless / in CI).
//

#if canImport(AppKit)
import Foundation
import Testing
@testable import BookmarkBridge

@Suite("OpenPanelSafariAccessAuthorizer")
@MainActor
struct OpenPanelSafariAccessAuthorizerTests {

    @Test("Returns the selected Bookmarks.plist URL")
    func returnsSelectedBookmarksFile() async throws {
        let url = URL(fileURLWithPath: "/Users/tester/Library/Safari/Bookmarks.plist")
        let authorizer = OpenPanelSafariAccessAuthorizer(runPanel: { url })

        #expect(try await authorizer.requestAccess() == url)
    }

    @Test("Throws cancelled when the user dismisses the panel")
    func cancellationThrowsCancelled() async {
        let authorizer = OpenPanelSafariAccessAuthorizer(runPanel: { nil })

        await #expect(throws: SafariAccessError.cancelled) {
            try await authorizer.requestAccess()
        }
    }

    @Test("Throws wrongFile when a non-Bookmarks.plist file is selected")
    func wrongFileThrowsWrongFile() async {
        let wrong = URL(fileURLWithPath: "/Users/tester/Downloads/Other.plist")
        let authorizer = OpenPanelSafariAccessAuthorizer(runPanel: { wrong })

        await #expect(throws: SafariAccessError.wrongFile(selected: wrong)) {
            try await authorizer.requestAccess()
        }
    }

    @Test("Validates only the file name; full-path validation is the coordinator's job")
    func acceptsBookmarksPlistByName() async throws {
        let url = URL(fileURLWithPath: "/anywhere/Bookmarks.plist")
        let authorizer = OpenPanelSafariAccessAuthorizer(runPanel: { url })

        #expect(try await authorizer.requestAccess() == url)
    }
}
#endif
