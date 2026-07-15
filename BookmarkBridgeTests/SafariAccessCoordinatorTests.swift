//
//  SafariAccessCoordinatorTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("SafariAccessCoordinator")
@MainActor
struct SafariAccessCoordinatorTests {

    private struct Boom: Error {}

    private let validURL = URL(fileURLWithPath: "/Users/tester/Library/Safari/Bookmarks.plist")
    private let bookmarkData = Data([0xAB, 0xCD])

    private func makeCoordinator(
        authorizer: FakeSafariAccessAuthorizer,
        creator: SecurityScopedBookmarkCreating,
        store: BookmarkStore
    ) -> SafariAccessCoordinator {
        SafariAccessCoordinator(authorizer: authorizer, creator: creator, store: store)
    }

    // MARK: - Success

    @Test("Authorizes, creates a bookmark, persists it, and returns the URL")
    func success() async throws {
        let authorizer = FakeSafariAccessAuthorizer(.success(validURL))
        let creator = StubBookmarkCreator(.success(bookmarkData))
        let store = InMemoryBookmarkStore()
        let coordinator = makeCoordinator(authorizer: authorizer, creator: creator, store: store)

        let returned = try await coordinator.authorize()

        #expect(returned == validURL)
        #expect(creator.requestedURLs == [validURL])
        #expect(store.saveCount == 1)
        #expect(try store.loadBookmark(for: .safari) == bookmarkData)
    }

    // MARK: - User cancels

    @Test("Propagates cancellation and does nothing else")
    func userCancels() async {
        let authorizer = FakeSafariAccessAuthorizer(.failure(SafariAccessError.cancelled))
        let creator = StubBookmarkCreator(.success(bookmarkData))
        let store = InMemoryBookmarkStore()
        let coordinator = makeCoordinator(authorizer: authorizer, creator: creator, store: store)

        await #expect(throws: SafariAccessError.cancelled) {
            try await coordinator.authorize()
        }
        #expect(creator.requestedURLs.isEmpty)
        #expect(store.saveCount == 0)
    }

    // MARK: - Wrong file

    @Test("Rejects a file that is not the expected Safari bookmarks file")
    func wrongFileSelected() async {
        let wrongURL = URL(fileURLWithPath: "/Users/tester/Downloads/Bookmarks.plist")
        let authorizer = FakeSafariAccessAuthorizer(.success(wrongURL))
        let creator = StubBookmarkCreator(.success(bookmarkData))
        let store = InMemoryBookmarkStore()
        let coordinator = makeCoordinator(authorizer: authorizer, creator: creator, store: store)

        await #expect(throws: SafariAccessError.wrongFile(selected: wrongURL)) {
            try await coordinator.authorize()
        }
        #expect(creator.requestedURLs.isEmpty)   // never silently accepted
        #expect(store.saveCount == 0)
    }

    @Test("Rejects a file with the right name but the wrong location")
    func wrongLocationSameName() async {
        let wrongURL = URL(fileURLWithPath: "/Users/tester/Library/Mail/Bookmarks.plist")
        let authorizer = FakeSafariAccessAuthorizer(.success(wrongURL))
        let coordinator = makeCoordinator(
            authorizer: authorizer,
            creator: StubBookmarkCreator(.success(bookmarkData)),
            store: InMemoryBookmarkStore()
        )

        await #expect(throws: SafariAccessError.wrongFile(selected: wrongURL)) {
            try await coordinator.authorize()
        }
    }

    // MARK: - Bookmark creation fails

    @Test("Surfaces bookmarkCreationFailed and does not persist")
    func bookmarkCreationFails() async {
        let authorizer = FakeSafariAccessAuthorizer(.success(validURL))
        let creator = StubBookmarkCreator(.failure(Boom()))
        let store = InMemoryBookmarkStore()
        let coordinator = makeCoordinator(authorizer: authorizer, creator: creator, store: store)

        await #expect(throws: SafariAccessError.bookmarkCreationFailed) {
            try await coordinator.authorize()
        }
        #expect(store.saveCount == 0)
    }

    // MARK: - Persistence fails

    @Test("Surfaces persistenceFailed when saving the bookmark fails")
    func persistenceFails() async {
        let authorizer = FakeSafariAccessAuthorizer(.success(validURL))
        let creator = StubBookmarkCreator(.success(bookmarkData))
        let store = InMemoryBookmarkStore()
        store.saveError = Boom()
        let coordinator = makeCoordinator(authorizer: authorizer, creator: creator, store: store)

        await #expect(throws: SafariAccessError.persistenceFailed) {
            try await coordinator.authorize()
        }
    }
}
