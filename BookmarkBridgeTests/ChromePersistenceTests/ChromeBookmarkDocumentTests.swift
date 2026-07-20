//
//  ChromeBookmarkDocumentTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("Chrome bookmark persistence document and validation")
struct ChromeBookmarkDocumentTests {
    private let validator = ChromeBookmarkValidator()

    @Test("A valid Chrome document with all permanent roots is accepted")
    func validDocument() throws {
        let document = try ChromePersistenceTestSupport.document()

        try validator.validate(document)

        let object = try ChromePersistenceTestSupport.object(from: document.data)
        let roots = try #require(object["roots"] as? [String: Any])
        #expect(Set(roots.keys) == ["bookmark_bar", "other", "synced"])
    }

    @Test("Invalid JSON is rejected")
    func invalidJSON() {
        let data = Data("not-json".utf8)
        #expect(throws: ChromePersistenceError.invalidJSON) {
            _ = try ChromeBookmarkDocument(
                data: data,
                sourceFingerprint: ChromePersistenceTestSupport.placeholderFingerprint(for: data)
            )
        }
    }

    @Test("A non-object JSON root is rejected")
    func invalidRoot() throws {
        let data = try ChromePersistenceTestSupport.data(["array-root"])
        #expect(throws: ChromePersistenceError.invalidJSON) {
            _ = try ChromeBookmarkDocument(
                data: data,
                sourceFingerprint: ChromePersistenceTestSupport.placeholderFingerprint(for: data)
            )
        }
    }

    @Test("Missing roots are rejected")
    func missingRoots() throws {
        let document = try ChromePersistenceTestSupport.document(["version": 1])
        #expect(throws: ChromePersistenceError.invalidStructure(.rootsMissing)) {
            try validator.validate(document)
        }
    }

    @Test("A non-object roots value is rejected")
    func invalidRoots() throws {
        let document = try ChromePersistenceTestSupport.document(["roots": []])
        #expect(throws: ChromePersistenceError.invalidStructure(.invalidRoots)) {
            try validator.validate(document)
        }
    }

    @Test("Every root must be a folder")
    func invalidRootNode() throws {
        let document = try ChromePersistenceTestSupport.document([
            "roots": [
                "bookmark_bar": ChromePersistenceTestSupport.bookmark(
                    id: "1",
                    GUID: "guid-1",
                    name: "Not a folder",
                    URL: "https://example.test"
                ),
            ],
        ])
        #expect(throws: ChromePersistenceError.invalidStructure(
            .invalidRoot(key: "bookmark_bar")
        )) {
            try validator.validate(document)
        }
    }

    @Test("An unknown permanent root is rejected before checksum persistence")
    func unknownRoot() throws {
        var object = ChromePersistenceTestSupport.validObject()
        var roots = try #require(object["roots"] as? [String: Any])
        roots["future_root"] = ChromePersistenceTestSupport.folder(
            id: "4",
            GUID: "root-guid-4",
            name: "Future Root",
            children: []
        )
        object["roots"] = roots
        let document = try ChromePersistenceTestSupport.document(object)

        #expect(throws: ChromePersistenceError.invalidStructure(
            .invalidRoot(key: "future_root")
        )) {
            try ChromeBookmarkValidator().validate(document)
        }
    }

    @Test("Folders require an array of children")
    func invalidFolder() throws {
        var root = ChromePersistenceTestSupport.folder(
            id: "1",
            GUID: "guid-1",
            name: "Folder",
            children: []
        )
        root.removeValue(forKey: "children")
        let document = try ChromePersistenceTestSupport.document([
            "roots": ["bookmark_bar": root],
        ])

        #expect(throws: ChromePersistenceError.invalidStructure(
            .invalidChildren(path: ["bookmark_bar"])
        )) {
            try validator.validate(document)
        }
    }

    @Test("URL nodes require a textual URL")
    func invalidBookmark() throws {
        var bookmark = ChromePersistenceTestSupport.bookmark(
            id: "2",
            GUID: "guid-2",
            name: "Bookmark",
            URL: "https://example.test"
        )
        bookmark.removeValue(forKey: "url")
        let root = ChromePersistenceTestSupport.folder(
            id: "1",
            GUID: "guid-1",
            name: "Folder",
            children: [bookmark]
        )
        let document = try ChromePersistenceTestSupport.document([
            "roots": ["bookmark_bar": root],
        ])

        #expect(throws: ChromePersistenceError.invalidStructure(
            .invalidURL(path: ["bookmark_bar", "0"])
        )) {
            try validator.validate(document)
        }
    }

    @Test("Unknown node types are rejected")
    func unknownType() throws {
        var child = ChromePersistenceTestSupport.bookmark(
            id: "2",
            GUID: "guid-2",
            name: "Unknown",
            URL: "https://example.test"
        )
        child["type"] = "separator"
        child.removeValue(forKey: "url")
        let document = try nestedDocument(child)

        #expect(throws: ChromePersistenceError.invalidStructure(
            .unknownNodeType(path: ["bookmark_bar", "0"])
        )) {
            try validator.validate(document)
        }
    }

    @Test("Every node requires a native id")
    func missingIdentifier() throws {
        var child = ChromePersistenceTestSupport.bookmark(
            id: "2",
            GUID: "guid-2",
            name: "Missing ID",
            URL: "https://example.test"
        )
        child.removeValue(forKey: "id")
        let document = try nestedDocument(child)

        #expect(throws: ChromePersistenceError.invalidStructure(
            .missingIdentifier(path: ["bookmark_bar", "0"])
        )) {
            try validator.validate(document)
        }
    }

    @Test("Native ids must be unique across all roots")
    func duplicateIdentifier() throws {
        var object = ChromePersistenceTestSupport.validObject()
        var roots = try #require(object["roots"] as? [String: Any])
        var other = try #require(roots["other"] as? [String: Any])
        other["id"] = "1"
        roots["other"] = other
        object["roots"] = roots
        let document = try ChromePersistenceTestSupport.document(object)

        #expect(throws: ChromePersistenceError.invalidStructure(.duplicateIdentifier("1"))) {
            try validator.validate(document)
        }
    }

    @Test("GUIDs used by the reader must also be unique")
    func duplicateGUID() throws {
        var object = ChromePersistenceTestSupport.validObject()
        var roots = try #require(object["roots"] as? [String: Any])
        var other = try #require(roots["other"] as? [String: Any])
        other["guid"] = "root-guid-1"
        roots["other"] = other
        object["roots"] = roots
        let document = try ChromePersistenceTestSupport.document(object)

        #expect(throws: ChromePersistenceError.invalidStructure(
            .duplicateGUID("root-guid-1")
        )) {
            try validator.validate(document)
        }
    }

    @Test("Unknown keys, ids, metadata, roots and JSON scalar types survive serialization")
    func preservesCompleteJSON() throws {
        let document = try ChromePersistenceTestSupport.document()
        let persisted = try document.dataForPersistence()
        let object = try ChromePersistenceTestSupport.object(from: persisted)
        let metadata = try #require(object["unknown_root_metadata"] as? [String: Any])
        let roots = try #require(object["roots"] as? [String: Any])
        let bar = try #require(roots["bookmark_bar"] as? [String: Any])
        let children = try #require(bar["children"] as? [[String: Any]])
        let bookmark = try #require(children.first)

        #expect(bar["id"] as? String == "1")
        #expect(bar["unknown_folder_key"] != nil)
        #expect(bookmark["meta_info"] != nil)
        #expect(bookmark["unknown_numeric_key"] as? Int == 42)
        #expect(metadata["enabled"] as? Bool == true)
        #expect(metadata["ratio"] as? Double == 1.5)
        #expect(metadata["count"] as? Int == 7)
        #expect(Set(roots.keys) == ["bookmark_bar", "other", "synced"])
    }

    @Test("An existing checksum is recomputed with the proven Chrome algorithm")
    func recomputesChecksum() throws {
        var object = ChromePersistenceTestSupport.validObject()
        object["checksum"] = "stale"
        let document = try ChromePersistenceTestSupport.document(object)
        let persisted = try ChromePersistenceTestSupport.object(
            from: document.dataForPersistence()
        )
        let roots = try #require(persisted["roots"] as? [String: Any])

        #expect(persisted["checksum"] as? String == ChromeChecksum.compute(roots: roots))
    }

    @Test("A missing checksum is preserved as missing")
    func doesNotInventChecksum() throws {
        let document = try ChromePersistenceTestSupport.document(
            ChromePersistenceTestSupport.validObject(checksum: false)
        )
        let persisted = try ChromePersistenceTestSupport.object(
            from: document.dataForPersistence()
        )

        #expect(persisted["checksum"] == nil)
    }

    @Test("Document, fingerprint and validator satisfy Sendable boundaries")
    func strictConcurrency() throws {
        let document = try ChromePersistenceTestSupport.document()
        requireSendable(document)
        requireSendable(document.sourceFingerprint)
        requireSendable(validator)
    }

    private func nestedDocument(_ child: [String: Any]) throws -> ChromeBookmarkDocument {
        try ChromePersistenceTestSupport.document([
            "roots": [
                "bookmark_bar": ChromePersistenceTestSupport.folder(
                    id: "1",
                    GUID: "guid-1",
                    name: "Folder",
                    children: [child]
                ),
            ],
        ])
    }

    private func requireSendable<T: Sendable>(_ value: T) { _ = value }
}
