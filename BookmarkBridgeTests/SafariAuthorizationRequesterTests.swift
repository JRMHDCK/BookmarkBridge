//
//  SafariAuthorizationRequesterTests.swift
//  BookmarkBridgeTests
//

#if os(macOS)
import Foundation
import Testing
@testable import BookmarkBridge

@Suite("SafariAuthorizationRequester")
@MainActor
struct SafariAuthorizationRequesterTests {

    private let safariURL = URL(fileURLWithPath: "/Users/tester/Library/Safari/Bookmarks.plist")

    private func makeRequester(
        panelOutcome: Result<URL, Error>,
        creator: SecurityScopedBookmarkCreating = StubBookmarkCreator(.success(Data([0x01]))),
        store: BookmarkStore = InMemoryBookmarkStore()
    ) -> SafariAuthorizationRequester {
        let coordinator = SafariAccessCoordinator(
            authorizer: FakeSafariAccessAuthorizer(panelOutcome),
            creator: creator,
            store: store
        )
        return SafariAuthorizationRequester(coordinator: coordinator)
    }

    @Test("Returns true and persists when authorization succeeds")
    func granted() async throws {
        let store = InMemoryBookmarkStore()
        let requester = makeRequester(panelOutcome: .success(safariURL), store: store)

        let granted = try await requester.requestAuthorization(for: .safari)

        #expect(granted)
        #expect(try store.loadBookmark(for: .safari) == Data([0x01]))
    }

    @Test("Returns false (no error) when the user cancels")
    func cancelled() async throws {
        let requester = makeRequester(panelOutcome: .failure(SafariAccessError.cancelled))

        let granted = try await requester.requestAuthorization(for: .safari)

        #expect(granted == false)
    }

    @Test("Propagates a genuine failure (wrong file)")
    func wrongFilePropagates() async {
        let wrongURL = URL(fileURLWithPath: "/Users/tester/Downloads/Bookmarks.plist")
        let requester = makeRequester(panelOutcome: .success(wrongURL))

        await #expect(throws: SafariAccessError.wrongFile(selected: wrongURL)) {
            try await requester.requestAuthorization(for: .safari)
        }
    }

    @Test("Rejects non-Safari browsers without invoking the coordinator")
    func rejectsNonSafari() async {
        let requester = makeRequester(panelOutcome: .success(safariURL))

        await #expect(throws: BookmarkError.unsupportedBrowser(.chrome)) {
            try await requester.requestAuthorization(for: .chrome)
        }
    }
}
#endif
