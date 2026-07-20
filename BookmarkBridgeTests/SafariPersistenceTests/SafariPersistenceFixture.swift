//
//  SafariPersistenceFixture.swift
//  BookmarkBridgeTests
//

import Foundation
@testable import BookmarkBridge

nonisolated enum SafariPersistenceFixture {
    static let rootUUID = "00000000-0000-0000-0000-000000000001"
    static let folderUUID = "00000000-0000-0000-0000-000000000010"
    static let bookmarkUUID = "00000000-0000-0000-0000-000000000011"
    static let metadataDate = Date(timeIntervalSinceReferenceDate: 700_000_000)
    static let metadataData = Data([0x00, 0x7F, 0xFF])

    static func propertyList() -> [String: Any] {
        [
            "WebBookmarkType": "WebBookmarkTypeList",
            "WebBookmarkUUID": rootUUID,
            "WebBookmarkFileVersion": 1,
            "Title": "",
            "UnknownRootMetadata": [
                "enabled": true,
                "count": 7,
                "ratio": 1.5,
                "date": metadataDate,
                "payload": metadataData,
            ],
            "Children": [
                [
                    "WebBookmarkType": "WebBookmarkTypeList",
                    "WebBookmarkUUID": folderUUID,
                    "Title": "BookmarksBar",
                    "UnknownFolderKey": "preserved",
                    "Children": [
                        [
                            "WebBookmarkType": "WebBookmarkTypeLeaf",
                            "WebBookmarkUUID": bookmarkUUID,
                            "URLString": "https://example.com",
                            "URIDictionary": ["title": "Example"],
                            "ReadingList": ["DateAdded": metadataDate],
                        ],
                    ],
                ],
            ],
        ]
    }

    static func data(
        from propertyList: [String: Any] = propertyList(),
        format: PropertyListSerialization.PropertyListFormat = .binary
    ) throws -> Data {
        try PropertyListSerialization.data(
            fromPropertyList: propertyList,
            format: format,
            options: 0
        )
    }

    static func temporaryDirectory() throws -> URL {
        let directoryURL = FileManager().temporaryDirectory.appendingPathComponent(
            "BookmarkBridge-SafariPersistence-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager().createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }

    static func writeBookmarks(in directory: URL, data: Data? = nil) throws -> URL {
        let fileURL = directory.appendingPathComponent("Bookmarks.plist", isDirectory: false)
        try (data ?? self.data()).write(to: fileURL)
        return fileURL
    }

    static func document(at fileURL: URL) throws -> SafariBookmarkDocument {
        let data = try Data(contentsOf: fileURL)
        return try SafariBookmarkDocument(
            data: data,
            sourceFingerprint: SafariDocumentFingerprint.capture(at: fileURL)
        )
    }

    static var placeholderFingerprint: SafariDocumentFingerprint {
        SafariDocumentFingerprint(
            contentDigest: Data(),
            fileSize: 0,
            modificationDate: .distantPast,
            fileSystemNumber: 0,
            fileNumber: 0
        )
    }
}
