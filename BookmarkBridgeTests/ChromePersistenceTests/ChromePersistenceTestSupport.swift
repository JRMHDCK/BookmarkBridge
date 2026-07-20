//
//  ChromePersistenceTestSupport.swift
//  BookmarkBridgeTests
//

import Foundation
@testable import BookmarkBridge

nonisolated enum ChromePersistenceTestSupport {
    static func validObject(checksum: Bool = true) -> [String: Any] {
        let roots: [String: Any] = [
            "bookmark_bar": folder(
                id: "1",
                GUID: "root-guid-1",
                name: "Bookmarks Bar",
                children: [
                    bookmark(
                        id: "10",
                        GUID: "bookmark-guid-10",
                        name: "Example",
                        URL: "https://example.test"
                    ),
                ]
            ),
            "other": folder(
                id: "2",
                GUID: "root-guid-2",
                name: "Other Bookmarks",
                children: [
                    folder(
                        id: "20",
                        GUID: "folder-guid-20",
                        name: "Nested",
                        children: []
                    ),
                ]
            ),
            "synced": folder(
                id: "3",
                GUID: "root-guid-3",
                name: "Mobile Bookmarks",
                children: []
            ),
        ]
        var object: [String: Any] = [
            "version": 1,
            "roots": roots,
            "unknown_root_metadata": [
                "enabled": true,
                "ratio": 1.5,
                "count": 7,
                "label": "preserved",
            ],
        ]
        if checksum {
            object["checksum"] = ChromeChecksum.compute(roots: roots)
        }
        return object
    }

    static func folder(
        id: String,
        GUID: String,
        name: String,
        children: [[String: Any]]
    ) -> [String: Any] {
        [
            "type": "folder",
            "id": id,
            "guid": GUID,
            "name": name,
            "children": children,
            "date_added": "13200000000000000",
            "date_modified": "13200000000000001",
            "unknown_folder_key": ["nested": true],
        ]
    }

    static func bookmark(
        id: String,
        GUID: String,
        name: String,
        URL: String
    ) -> [String: Any] {
        [
            "type": "url",
            "id": id,
            "guid": GUID,
            "name": name,
            "url": URL,
            "date_added": "13200000000000002",
            "meta_info": ["power_bookmark_meta": "opaque"],
            "unknown_numeric_key": 42,
        ]
    }

    static func data(_ object: Any = validObject()) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    static func object(from data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ChromePersistenceError.invalidJSON
        }
        return object
    }

    static func placeholderFingerprint(for data: Data) -> ChromeDocumentFingerprint {
        ChromeDocumentFingerprint(
            contentDigest: ChromeDocumentFingerprint.digest(of: data),
            fileSize: UInt64(data.count),
            modificationDate: Date(timeIntervalSinceReferenceDate: 0),
            fileSystemNumber: 1,
            fileNumber: 1
        )
    }

    static func document(_ object: Any = validObject()) throws -> ChromeBookmarkDocument {
        let data = try data(object)
        return try ChromeBookmarkDocument(
            data: data,
            sourceFingerprint: placeholderFingerprint(for: data)
        )
    }

    static func temporaryDirectory() throws -> URL {
        let URL = FileManager.default.temporaryDirectory.appending(
            path: "BookmarkBridge-ChromePersistence-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: URL, withIntermediateDirectories: true)
        return URL
    }

    static func writeBookmarks(
        in directory: URL,
        object: Any = validObject()
    ) throws -> URL {
        let URL = directory.appending(path: "Bookmarks")
        try data(object).write(to: URL)
        return URL
    }
}

nonisolated struct ClosedChromeChecker: ChromeApplicationStateChecking {
    func ensureChromeIsClosed() throws {}
}
