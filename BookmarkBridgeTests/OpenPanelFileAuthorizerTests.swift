//
//  OpenPanelFileAuthorizerTests.swift
//  BookmarkBridgeTests
//
//  Exercises the file authorizer's mapping logic (selection → URL, cancellation,
//  wrong file) by injecting the panel outcome. The real NSOpenPanel presentation
//  requires a GUI session and is intentionally NOT unit-tested.
//

#if canImport(AppKit)
import Foundation
import Testing
@testable import BookmarkBridge

@Suite("OpenPanelFileAuthorizer")
@MainActor
struct OpenPanelFileAuthorizerTests {

    @Test("Returns the selected Bookmarks.plist URL")
    func returnsSelectedBookmarksFile() async throws {
        let url = URL(fileURLWithPath: "/Users/tester/Library/Safari/Bookmarks.plist")
        let authorizer = OpenPanelFileAuthorizer(runPanel: { url })

        #expect(try await authorizer.requestAccess() == url)
    }

    @Test("Throws cancelled when the user dismisses the panel")
    func cancellationThrowsCancelled() async {
        let authorizer = OpenPanelFileAuthorizer(runPanel: { nil })

        await #expect(throws: AccessError.cancelled) {
            try await authorizer.requestAccess()
        }
    }

    @Test("Throws wrongFile when a non-Bookmarks.plist file is selected")
    func wrongFileThrowsWrongFile() async {
        let wrong = URL(fileURLWithPath: "/Users/tester/Downloads/Other.plist")
        let authorizer = OpenPanelFileAuthorizer(runPanel: { wrong })

        await #expect(throws: AccessError.wrongFile(selected: wrong)) {
            try await authorizer.requestAccess()
        }
    }

    @Test("Validates only the file name; full-path validation is the coordinator's job")
    func acceptsBookmarksPlistByName() async throws {
        let url = URL(fileURLWithPath: "/anywhere/Bookmarks.plist")
        let authorizer = OpenPanelFileAuthorizer(runPanel: { url })

        #expect(try await authorizer.requestAccess() == url)
    }
}
#endif
