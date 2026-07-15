//
//  OpenPanelDirectoryAuthorizerTests.swift
//  BookmarkBridgeTests
//
//  Exercises the directory authorizer's mapping logic by injecting the panel
//  outcome. The real NSOpenPanel presentation requires a GUI session and is
//  intentionally NOT unit-tested.
//

#if canImport(AppKit)
import Foundation
import Testing
@testable import BookmarkBridge

@Suite("OpenPanelDirectoryAuthorizer")
@MainActor
struct OpenPanelDirectoryAuthorizerTests {

    @Test("Returns the selected directory URL")
    func returnsSelectedDirectory() async throws {
        let directory = URL(
            fileURLWithPath: "/Users/tester/Library/Application Support/Google/Chrome",
            isDirectory: true
        )
        let authorizer = OpenPanelDirectoryAuthorizer(runPanel: { directory })

        #expect(try await authorizer.requestAccess() == directory)
    }

    @Test("Throws cancelled when the user dismisses the panel")
    func cancellationThrowsCancelled() async {
        let authorizer = OpenPanelDirectoryAuthorizer(runPanel: { nil })

        await #expect(throws: AccessError.cancelled) {
            try await authorizer.requestAccess()
        }
    }
}
#endif
