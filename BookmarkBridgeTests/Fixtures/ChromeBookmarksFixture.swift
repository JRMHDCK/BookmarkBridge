//
//  ChromeBookmarksFixture.swift
//  BookmarkBridgeTests
//
//  Programmatically generated, fully anonymized Chrome `Bookmarks` (JSON) content
//  used by the Chrome reading tests. It never copies or reads a real file, so it
//  is reproducible on every machine and in CI.
//
//  Format reference (Chrome): a top-level object `{ checksum, version, roots }`
//  where `roots` has `bookmark_bar`, `other`, and `synced`, each a folder node.
//  A node is `{ "type": "folder", name, id, guid, children, ... }` or
//  `{ "type": "url", name, id, guid, url, date_added }`. `date_added` is a string
//  of microseconds since 1601-01-01 UTC.
//

import Foundation

enum ChromeBookmarksFixture {

    /// Stable values reused by assertions here and in the decoder tests.
    enum Expected {
        static let barName = "Bookmarks bar"
        static let otherName = "Other bookmarks"
        static let syncedName = "Mobile bookmarks"
        static let devName = "Dev"
        static let emptyFolderName = "Dossier vide"

        static let exampleName = "Example"
        static let exampleURL = "https://www.example.com/"

        static let unicodeName = "Café ☕︎ 日本語 — Ω"
        static let unicodeURL = "https://unicode.example/página"

        static let emptyTitleName = ""
        static let emptyTitleURL = "https://no-title.example/"

        /// Unusual but valid: a non-http scheme.
        static let unusualURL = "mailto:contact@example.org"

        static let swiftName = "Swift"
        static let swiftURL = "https://swift.org/"

        static let otherItemName = "Example.org"
        static let otherItemURL = "https://example.org/"

        static let mobileItemName = "Lecture mobile"
        static let mobileItemURL = "https://mobile.example/read"

        /// 2023-01-01T00:00:00Z expressed as Chrome microseconds since 1601.
        static let dateAddedString = "13317004800000000"
    }

    // MARK: - Public API

    /// The raw JSON object (Chrome's on-disk structure).
    ///
    /// - Parameter includeSyncedItem: when `true`, the `synced` (mobile) root
    ///   contains a bookmark; otherwise it is present but empty.
    static func propertyList(includeSyncedItem: Bool = false) -> [String: Any] {
        let bar = folder(id: "1", name: Expected.barName, children: [
            leaf(id: "5", name: Expected.exampleName, url: Expected.exampleURL),
            leaf(id: "6", name: Expected.unicodeName, url: Expected.unicodeURL),
            leaf(id: "7", name: Expected.emptyTitleName, url: Expected.emptyTitleURL),
            leaf(id: "8", name: "Contact", url: Expected.unusualURL),
            folder(id: "10", name: Expected.devName, children: [
                leaf(id: "11", name: Expected.swiftName, url: Expected.swiftURL),
                folder(id: "12", name: Expected.emptyFolderName, children: []),
            ]),
        ])
        let other = folder(id: "2", name: Expected.otherName, children: [
            leaf(id: "20", name: Expected.otherItemName, url: Expected.otherItemURL),
        ])
        let syncedChildren = includeSyncedItem
            ? [leaf(id: "30", name: Expected.mobileItemName, url: Expected.mobileItemURL)]
            : []
        let synced = folder(id: "3", name: Expected.syncedName, children: syncedChildren)

        return [
            "checksum": "00000000000000000000000000000000",
            "version": 1,
            "roots": [
                "bookmark_bar": bar,
                "other": other,
                "synced": synced,
            ],
        ]
    }

    static func data(includeSyncedItem: Bool = false) throws -> Data {
        try JSONSerialization.data(
            fromPropertyListCompatible: propertyList(includeSyncedItem: includeSyncedItem)
        )
    }

    // MARK: - Builders

    private static func leaf(id: String, name: String, url: String) -> [String: Any] {
        [
            "type": "url",
            "id": id,
            "guid": "guid-\(id)",
            "name": name,
            "url": url,
            "date_added": Expected.dateAddedString,
        ]
    }

    private static func folder(id: String, name: String, children: [[String: Any]]) -> [String: Any] {
        [
            "type": "folder",
            "id": id,
            "guid": "guid-\(id)",
            "name": name,
            "date_added": Expected.dateAddedString,
            "date_modified": Expected.dateAddedString,
            "children": children,
        ]
    }
}

extension JSONSerialization {
    /// Serializes a JSON-object dictionary to `Data`.
    static func data(fromPropertyListCompatible object: [String: Any]) throws -> Data {
        try data(withJSONObject: object, options: [])
    }
}
