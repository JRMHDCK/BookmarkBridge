//
//  SafariRealChainIntegrationTests.swift
//  BookmarkBridgeTests
//
//  End-to-end technical validation of the REAL access chain — using the real
//  Foundation security-scoped bookmark APIs, real read-only file access, and the
//  real decoder — but against a TEMPORARY fixture file, never ~/Library/Safari.
//
//  Chain exercised (NSOpenPanel replaced by a fake authorizer, real Safari file
//  replaced by a temp fixture):
//    SafariAccessCoordinator → SystemSecurityScopedBookmarkCreator → BookmarkStore
//    → [simulated restart] → AuthorizedSafariSourceLocator
//    → SandboxFileAccessProvider → SafariBookmarkReader → SafariBookmarkDecoder
//    → BookmarkTree
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("Safari real-chain integration (temporary file)")
@MainActor
struct SafariRealChainIntegrationTests {

    @Test("Full chain via a persisted security-scoped bookmark, read-only")
    func endToEndThroughPersistedBookmark() async throws {
        let fileManager = FileManager.default
        let workDir = fileManager.temporaryDirectory
            .appending(path: "bb-e2e-\(UUID().uuidString)", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: workDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: workDir) }

        // Stand-in for the real Safari file.
        let bookmarksFile = workDir.appending(path: "Bookmarks.plist", directoryHint: .notDirectory)
        try SafariBookmarksFixture.data().write(to: bookmarksFile)

        // Stand-in for Application Support.
        let storeDirectory = workDir.appending(path: "AppSupport", directoryHint: .isDirectory)

        // --- 1. Authorization: fake panel + REAL creator + REAL store ---
        let coordinator = SafariAccessCoordinator(
            authorizer: FakeSafariAccessAuthorizer(.success(bookmarksFile)),
            creator: SystemSecurityScopedBookmarkCreator(),
            store: ApplicationSupportBookmarkStore(directory: storeDirectory),
            expectedPathSuffix: "Bookmarks.plist"
        )
        let authorizedURL = try await coordinator.authorize()
        #expect(authorizedURL == bookmarksFile)

        // Read-only proof: capture file identity before reading.
        let attributesBefore = try fileManager.attributesOfItem(atPath: bookmarksFile.path(percentEncoded: false))
        let sizeBefore = attributesBefore[.size] as? Int
        let modifiedBefore = attributesBefore[.modificationDate] as? Date

        // --- 2. Simulated restart: a brand-new store instance + fresh chain ---
        let freshStore = ApplicationSupportBookmarkStore(directory: storeDirectory)
        let locator = AuthorizedSafariSourceLocator(
            store: freshStore,
            resolver: SystemSecurityScopedBookmarkResolver(),
            creator: SystemSecurityScopedBookmarkCreator()
        )
        let reader = SafariBookmarkReader(
            locator: locator,
            fileAccess: SandboxFileAccessProvider(),
            decoder: SafariBookmarkDecoder()
        )

        // --- 3. Read the file through the persisted bookmark ---
        let tree = try await reader.readBookmarkTree()

        // Read-only proof: file identity unchanged after reading.
        let attributesAfter = try fileManager.attributesOfItem(atPath: bookmarksFile.path(percentEncoded: false))
        #expect((attributesAfter[.size] as? Int) == sizeBefore)
        #expect((attributesAfter[.modificationDate] as? Date) == modifiedBefore)

        // --- 4. Validate the resulting tree ---
        #expect(tree.browser == .safari)
        #expect(tree.roots.count == 3)
        #expect(tree.bookmarkCount == 7)
        #expect(tree.capturedAt != .distantPast)
    }
}
