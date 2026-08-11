//
//  ChromeProfileBookmarkFileResolverTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("Chrome profile bookmark file resolver")
struct ChromeProfileBookmarkFileResolverTests {
    @Test("Resolves an account-only profile to AccountBookmarks")
    func resolvesAccountOnlyProfile() throws {
        let fixture = try makeProfile(
            name: "Profile 6",
            localData: nil,
            accountData: ChromeBookmarksFixture.data()
        )
        defer { fixture.remove() }

        let resolved = try makeResolver().resolve(
            profileDirectory: "Profile 6",
            in: fixture.location
        )

        #expect(resolved.kind == .account)
        #expect(resolved.url.lastPathComponent == "AccountBookmarks")
    }

    @Test("Resolves a local-only profile to Bookmarks")
    func resolvesLocalOnlyProfile() throws {
        let fixture = try makeProfile(
            name: "Profile 3",
            localData: ChromeBookmarksFixture.data(),
            accountData: nil
        )
        defer { fixture.remove() }

        let resolved = try makeResolver().resolve(
            profileDirectory: "Profile 3",
            in: fixture.location
        )

        #expect(resolved.kind == .local)
        #expect(resolved.url.lastPathComponent == "Bookmarks")
    }

    @Test("Keeps local storage when AccountBookmarks is empty")
    func emptyAccountStoreUsesLocalFile() throws {
        let fixture = try makeProfile(
            name: "Profile 2",
            localData: ChromeBookmarksFixture.data(),
            accountData: try emptyBookmarksData()
        )
        defer { fixture.remove() }

        let resolved = try makeResolver().resolve(
            profileDirectory: "Profile 2",
            in: fixture.location
        )

        #expect(resolved.kind == .local)
        #expect(resolved.url.lastPathComponent == "Bookmarks")
    }

    @Test("Refuses a profile with two active stores")
    func refusesAmbiguousProfile() throws {
        let fixture = try makeProfile(
            name: "Profile 2",
            localData: ChromeBookmarksFixture.data(),
            accountData: ChromeBookmarksFixture.data(includeSyncedItem: true)
        )
        defer { fixture.remove() }

        #expect(throws: BookmarkError.multipleBookmarkStores(.chrome)) {
            _ = try makeResolver().resolve(
                profileDirectory: "Profile 2",
                in: fixture.location
            )
        }
    }

    private func makeResolver() -> DefaultChromeProfileBookmarkFileResolver {
        DefaultChromeProfileBookmarkFileResolver(
            profileLocator: DefaultChromeProfileLocator(),
            decoder: ChromeBookmarkDecoder()
        )
    }

    private func makeProfile(
        name: String,
        localData: Data?,
        accountData: Data?
    ) throws -> ChromeProfileFixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "bb-profile-resolution-\(UUID().uuidString)",
                isDirectory: true
            )
        let chromeDirectory = root.appendingPathComponent(
            "Chrome",
            isDirectory: true
        )
        let profileDirectory = chromeDirectory.appendingPathComponent(
            name,
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: profileDirectory,
            withIntermediateDirectories: true
        )
        if let localData {
            try localData.write(
                to: profileDirectory.appendingPathComponent("Bookmarks")
            )
        }
        if let accountData {
            try accountData.write(
                to: profileDirectory.appendingPathComponent(
                    "AccountBookmarks"
                )
            )
        }
        return ChromeProfileFixture(
            root: root,
            location: BrowserLocation(
                browser: .chrome,
                fileURL: chromeDirectory
            )
        )
    }

    private func emptyBookmarksData() throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "version": 1,
            "checksum": "0",
            "roots": [
                "bookmark_bar": emptyFolder(id: "1", name: "Bar"),
                "other": emptyFolder(id: "2", name: "Other"),
                "synced": emptyFolder(id: "3", name: "Mobile"),
            ],
        ])
    }

    private func emptyFolder(id: String, name: String) -> [String: Any] {
        [
            "type": "folder",
            "id": id,
            "name": name,
            "children": [],
        ]
    }
}

nonisolated private struct ChromeProfileFixture: Sendable {
    let root: URL
    let location: BrowserLocation

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}
