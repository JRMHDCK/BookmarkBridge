//
//  AuthorizedSafariSourceLocatorTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("AuthorizedSafariSourceLocator")
struct AuthorizedSafariSourceLocatorTests {

    private struct Boom: Error {}

    private let safariURL = URL(fileURLWithPath: "/Users/tester/Library/Safari/Bookmarks.plist")
    private let storedBookmark = Data([0x01, 0x02, 0x03])

    private func makeLocator(
        store: BookmarkStore,
        resolver: SecurityScopedBookmarkResolving,
        creator: SecurityScopedBookmarkCreating = StubBookmarkCreator(.success(Data()))
    ) -> AuthorizedSafariSourceLocator {
        AuthorizedSafariSourceLocator(store: store, resolver: resolver, creator: creator)
    }

    // MARK: - Valid bookmark

    @Test("Returns the resolved location for a valid bookmark, without refreshing")
    func validBookmark() throws {
        let store = InMemoryBookmarkStore()
        store.preset(storedBookmark, for: .safari)
        let resolver = StubBookmarkResolver(.success(ResolvedBookmark(url: safariURL, isStale: false)))
        let creator = StubBookmarkCreator(.success(Data([0xFF])))
        let locator = makeLocator(store: store, resolver: resolver, creator: creator)

        let location = try locator.locate(.safari)

        #expect(location.browser == .safari)
        #expect(location.fileURL == safariURL)
        #expect(resolver.resolvedData == [storedBookmark])
        #expect(creator.requestedURLs.isEmpty)   // not refreshed
        #expect(store.saveCount == 0)
    }

    // MARK: - Stale bookmark

    @Test("Refreshes and re-saves a stale bookmark, then returns the location")
    func staleBookmarkRefreshed() throws {
        let store = InMemoryBookmarkStore()
        store.preset(storedBookmark, for: .safari)
        let resolver = StubBookmarkResolver(.success(ResolvedBookmark(url: safariURL, isStale: true)))
        let refreshed = Data([0x09, 0x09])
        let creator = StubBookmarkCreator(.success(refreshed))
        let locator = makeLocator(store: store, resolver: resolver, creator: creator)

        let location = try locator.locate(.safari)

        #expect(location.fileURL == safariURL)
        #expect(creator.requestedURLs == [safariURL])
        #expect(store.saveCount == 1)
        #expect(try store.loadBookmark(for: .safari) == refreshed)
    }

    @Test("Stale refresh is best-effort: still returns the location if recreation fails")
    func staleRefreshCreatorFails() throws {
        let store = InMemoryBookmarkStore()
        store.preset(storedBookmark, for: .safari)
        let resolver = StubBookmarkResolver(.success(ResolvedBookmark(url: safariURL, isStale: true)))
        let creator = StubBookmarkCreator(.failure(Boom()))
        let locator = makeLocator(store: store, resolver: resolver, creator: creator)

        let location = try locator.locate(.safari)

        #expect(location.fileURL == safariURL)
        #expect(store.saveCount == 0)
    }

    @Test("Stale refresh is best-effort: still returns the location if saving fails")
    func staleRefreshSaveFails() throws {
        let store = InMemoryBookmarkStore()
        store.preset(storedBookmark, for: .safari)
        store.saveError = Boom()
        let resolver = StubBookmarkResolver(.success(ResolvedBookmark(url: safariURL, isStale: true)))
        let creator = StubBookmarkCreator(.success(Data([0x09])))
        let locator = makeLocator(store: store, resolver: resolver, creator: creator)

        let location = try locator.locate(.safari)

        #expect(location.fileURL == safariURL)
        #expect(store.saveCount == 0)
    }

    // MARK: - authorizationRequired

    @Test("Throws authorizationRequired when no bookmark is stored")
    func absentBookmark() {
        let store = InMemoryBookmarkStore()  // empty
        let resolver = StubBookmarkResolver(.success(ResolvedBookmark(url: safariURL, isStale: false)))
        let locator = makeLocator(store: store, resolver: resolver)

        #expect(throws: BookmarkError.authorizationRequired(.safari)) {
            _ = try locator.locate(.safari)
        }
        #expect(resolver.resolvedData.isEmpty)   // never attempted to resolve
    }

    @Test("Throws authorizationRequired when stored data is corrupted")
    func corruptedStore() {
        let store = InMemoryBookmarkStore()
        store.loadError = BookmarkStoreError.corruptedData
        let resolver = StubBookmarkResolver(.success(ResolvedBookmark(url: safariURL, isStale: false)))
        let locator = makeLocator(store: store, resolver: resolver)

        #expect(throws: BookmarkError.authorizationRequired(.safari)) {
            _ = try locator.locate(.safari)
        }
        #expect(resolver.resolvedData.isEmpty)
    }

    @Test("Throws authorizationRequired when the bookmark cannot be resolved")
    func unresolvableBookmark() {
        let store = InMemoryBookmarkStore()
        store.preset(storedBookmark, for: .safari)
        let resolver = StubBookmarkResolver(.failure(Boom()))
        let locator = makeLocator(store: store, resolver: resolver)

        #expect(throws: BookmarkError.authorizationRequired(.safari)) {
            _ = try locator.locate(.safari)
        }
    }

    // MARK: - Browser guard & forwarding

    @Test("Rejects non-Safari browsers")
    func rejectsOtherBrowser() {
        let store = InMemoryBookmarkStore()
        let resolver = StubBookmarkResolver(.success(ResolvedBookmark(url: safariURL, isStale: false)))
        let locator = makeLocator(store: store, resolver: resolver)

        #expect(throws: BookmarkError.unsupportedBrowser(.chrome)) {
            _ = try locator.locate(.chrome)
        }
    }

    @Test("Forwards the resolved URL verbatim and never reads a real file")
    func forwardsResolvedURLVerbatim() throws {
        // Even an unexpected URL is forwarded as-is: validating the selected file
        // is the coordinator's job at authorization time, not the locator's.
        let unexpected = URL(fileURLWithPath: "/somewhere/else/Other.plist")
        let store = InMemoryBookmarkStore()
        store.preset(storedBookmark, for: .safari)
        let resolver = StubBookmarkResolver(.success(ResolvedBookmark(url: unexpected, isStale: false)))
        let locator = makeLocator(store: store, resolver: resolver)

        let location = try locator.locate(.safari)

        #expect(location.fileURL == unexpected)
    }
}
