//
//  SafariBookmarksFixture.swift
//  BookmarkBridgeTests
//
//  Programmatically generated, fully anonymized Safari `Bookmarks.plist`
//  content used by the Safari reading tests. It never copies or reads a real
//  file, so it is byte-for-byte reproducible on every machine and in CI.
//
//  Format reference (Safari): the root is a `WebBookmarkTypeList` whose
//  `Children` mix `WebBookmarkTypeLeaf` (a bookmark: `URLString` +
//  `URIDictionary.title`) and `WebBookmarkTypeList` (a folder: `Title` +
//  `Children`). The Bookmarks Bar is a list titled "BookmarksBar"; the Reading
//  List is a list titled "com.apple.ReadingList".
//

import Foundation

enum SafariBookmarksFixture {

    /// Stable values reused by assertions here and in the parser tests.
    enum Expected {
        static let bookmarksBarTitle = "BookmarksBar"
        static let readingListTitle = "com.apple.ReadingList"
        static let personalFolderTitle = "Personnel"
        static let devFolderTitle = "Dev"
        static let emptyFolderTitle = "Dossier vide"

        static let exampleTitle = "Example"
        static let exampleURL = "https://www.example.com"

        static let unicodeTitle = "Café ☕︎ 日本語 — Ω"
        static let unicodeURL = "https://unicode.example/página"

        static let emptyTitle = ""
        static let emptyTitleURL = "https://no-title.example"

        /// Unusual but valid: a non-http scheme.
        static let unusualURL = "mailto:contact@example.org"

        static let swiftTitle = "Swift"
        static let swiftURL = "https://swift.org"

        static let readingListTitleItem = "Article à lire"
        static let readingListURL = "https://read-later.example/article"
    }

    // MARK: - Public API

    /// The raw property-list dictionary (Safari's on-disk structure).
    static func propertyList() -> [String: Any] {
        [
            "WebBookmarkType": "WebBookmarkTypeList",
            "Title": "",
            "WebBookmarkUUID": "00000000-0000-0000-0000-000000000001",
            "WebBookmarkFileVersion": 1,
            "Children": [
                bookmarksBar(),
                personalFolder(),
                readingList(),
            ],
        ]
    }

    /// The fixture serialized as a **binary** property list, matching the real
    /// Safari file format that the decoder must handle.
    static func data() throws -> Data {
        try PropertyListSerialization.data(
            fromPropertyList: propertyList(),
            format: .binary,
            options: 0
        )
    }

    // MARK: - Sections

    private static func bookmarksBar() -> [String: Any] {
        list(
            uuid: "00000000-0000-0000-0000-000000000010",
            title: Expected.bookmarksBarTitle,
            children: [
                leaf(uuid: "…011", title: Expected.exampleTitle, url: Expected.exampleURL),
                leaf(uuid: "…012", title: Expected.unicodeTitle, url: Expected.unicodeURL),
                leaf(uuid: "…013", title: Expected.emptyTitle, url: Expected.emptyTitleURL),
                leaf(uuid: "…014", title: "Contact", url: Expected.unusualURL),
                devFolder(),
            ]
        )
    }

    private static func devFolder() -> [String: Any] {
        list(
            uuid: "00000000-0000-0000-0000-000000000020",
            title: Expected.devFolderTitle,
            children: [
                leaf(uuid: "…021", title: Expected.swiftTitle, url: Expected.swiftURL),
                // A nested, deliberately empty folder.
                list(uuid: "00000000-0000-0000-0000-000000000022",
                     title: Expected.emptyFolderTitle,
                     children: []),
            ]
        )
    }

    private static func personalFolder() -> [String: Any] {
        list(
            uuid: "00000000-0000-0000-0000-000000000030",
            title: Expected.personalFolderTitle,
            children: [
                leaf(uuid: "…031", title: "Example.org", url: "https://example.org"),
            ]
        )
    }

    private static func readingList() -> [String: Any] {
        list(
            uuid: "00000000-0000-0000-0000-000000000040",
            title: Expected.readingListTitle,
            children: [
                leaf(
                    uuid: "…041",
                    title: Expected.readingListTitleItem,
                    url: Expected.readingListURL,
                    extra: [
                        "ReadingList": [
                            "DateAdded": Date(timeIntervalSinceReferenceDate: 700_000_000),
                            "PreviewText": "Un court extrait anonymisé.",
                        ]
                    ]
                ),
            ]
        )
    }

    // MARK: - Builders

    private static func leaf(
        uuid: String,
        title: String,
        url: String,
        extra: [String: Any] = [:]
    ) -> [String: Any] {
        var entry: [String: Any] = [
            "WebBookmarkType": "WebBookmarkTypeLeaf",
            "URLString": url,
            "URIDictionary": ["title": title],
            "WebBookmarkUUID": uuid,
        ]
        for (key, value) in extra {
            entry[key] = value
        }
        return entry
    }

    private static func list(
        uuid: String,
        title: String,
        children: [[String: Any]]
    ) -> [String: Any] {
        [
            "WebBookmarkType": "WebBookmarkTypeList",
            "Title": title,
            "WebBookmarkUUID": uuid,
            "Children": children,
        ]
    }
}
