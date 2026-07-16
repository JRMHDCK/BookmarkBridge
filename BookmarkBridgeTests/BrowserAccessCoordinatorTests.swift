//
//  BrowserAccessCoordinatorTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("BrowserAccessCoordinator")
@MainActor
struct BrowserAccessCoordinatorTests {

    private struct Boom: Error {}

    private let validURL = URL(fileURLWithPath: "/Users/tester/Library/Safari/Bookmarks.plist")
    private let bookmarkData = Data([0xAB, 0xCD])

    private func makeSafariCoordinator(
        authorizer: FakeAccessAuthorizer,
        creator: SecurityScopedBookmarkCreating,
        store: BookmarkStore
    ) -> BrowserAccessCoordinator {
        BrowserAccessCoordinator(
            browser: .safari,
            expectedPathSuffix: BrowserAccessCoordinator.safariPathSuffix,
            authorizer: authorizer,
            creator: creator,
            store: store
        )
    }

    // MARK: - Success

    @Test("Authorizes, creates a bookmark, persists it, and returns the URL")
    func success() async throws {
        let creator = StubBookmarkCreator(.success(bookmarkData))
        let store = InMemoryBookmarkStore()
        let coordinator = makeSafariCoordinator(
            authorizer: FakeAccessAuthorizer(.success(validURL)),
            creator: creator,
            store: store
        )

        let returned = try await coordinator.authorize()

        #expect(returned == validURL)
        #expect(creator.requestedURLs == [validURL])
        #expect(store.saveCount == 1)
        #expect(try store.loadBookmark(for: .safari) == bookmarkData)
    }

    @Test("Works for a Chrome directory selection (persisted under .chrome)")
    func chromeDirectory() async throws {
        let directory = URL(
            fileURLWithPath: "/Users/tester/Library/Application Support/Google/Chrome",
            isDirectory: true
        )
        let store = InMemoryBookmarkStore()
        let coordinator = BrowserAccessCoordinator(
            browser: .chrome,
            expectedPathSuffix: BrowserAccessCoordinator.chromeDirectorySuffix,
            authorizer: FakeAccessAuthorizer(.success(directory)),
            creator: StubBookmarkCreator(.success(bookmarkData)),
            store: store
        )

        let returned = try await coordinator.authorize()

        #expect(returned == directory)
        #expect(try store.loadBookmark(for: .chrome) == bookmarkData)
    }

    // MARK: - User cancels

    @Test("Propagates cancellation and does nothing else")
    func userCancels() async {
        let creator = StubBookmarkCreator(.success(bookmarkData))
        let store = InMemoryBookmarkStore()
        let coordinator = makeSafariCoordinator(
            authorizer: FakeAccessAuthorizer(.failure(AccessError.cancelled)),
            creator: creator,
            store: store
        )

        await #expect(throws: AccessError.cancelled) {
            try await coordinator.authorize()
        }
        #expect(creator.requestedURLs.isEmpty)
        #expect(store.saveCount == 0)
    }

    // MARK: - Wrong selection

    @Test("Rejects a file that is not the expected Safari bookmarks file")
    func wrongFileSelected() async {
        let wrongURL = URL(fileURLWithPath: "/Users/tester/Downloads/Bookmarks.plist")
        let creator = StubBookmarkCreator(.success(bookmarkData))
        let store = InMemoryBookmarkStore()
        let coordinator = makeSafariCoordinator(
            authorizer: FakeAccessAuthorizer(.success(wrongURL)),
            creator: creator,
            store: store
        )

        await #expect(throws: AccessError.wrongFile(selected: wrongURL)) {
            try await coordinator.authorize()
        }
        #expect(creator.requestedURLs.isEmpty)   // never silently accepted
        #expect(store.saveCount == 0)
    }

    @Test("Rejects a file with the right name but the wrong location")
    func wrongLocationSameName() async {
        let wrongURL = URL(fileURLWithPath: "/Users/tester/Library/Mail/Bookmarks.plist")
        let coordinator = makeSafariCoordinator(
            authorizer: FakeAccessAuthorizer(.success(wrongURL)),
            creator: StubBookmarkCreator(.success(bookmarkData)),
            store: InMemoryBookmarkStore()
        )

        await #expect(throws: AccessError.wrongFile(selected: wrongURL)) {
            try await coordinator.authorize()
        }
    }

    // MARK: - Bookmark creation fails

    @Test("Surfaces bookmarkCreationFailed and does not persist")
    func bookmarkCreationFails() async {
        let store = InMemoryBookmarkStore()
        let coordinator = makeSafariCoordinator(
            authorizer: FakeAccessAuthorizer(.success(validURL)),
            creator: StubBookmarkCreator(.failure(Boom())),
            store: store
        )

        await #expect(throws: AccessError.bookmarkCreationFailed) {
            try await coordinator.authorize()
        }
        #expect(store.saveCount == 0)
    }

    // MARK: - Persistence fails

    @Test("Surfaces persistenceFailed when saving the bookmark fails")
    func persistenceFails() async {
        let store = InMemoryBookmarkStore()
        store.saveError = Boom()
        let coordinator = makeSafariCoordinator(
            authorizer: FakeAccessAuthorizer(.success(validURL)),
            creator: StubBookmarkCreator(.success(bookmarkData)),
            store: store
        )

        await #expect(throws: AccessError.persistenceFailed) {
            try await coordinator.authorize()
        }
    }
}
