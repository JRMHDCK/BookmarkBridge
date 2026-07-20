//
//  SafariBookmarkDocumentTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("Safari bookmark persistence document")
struct SafariBookmarkDocumentTests {
    @Test("Binary plist parsing records its format")
    func binaryFormat() throws {
        let document = try SafariBookmarkDocument(
            data: SafariPersistenceFixture.data(),
            sourceFingerprint: SafariPersistenceFixture.placeholderFingerprint
        )

        #expect(document.format == .binary)
    }

    @Test("Invalid plist data is rejected")
    func invalidPropertyList() {
        #expect(throws: SafariPersistenceError.invalidPropertyList) {
            _ = try SafariBookmarkDocument(
                data: Data("not a plist".utf8),
                sourceFingerprint: SafariPersistenceFixture.placeholderFingerprint
            )
        }
    }

    @Test("Original bytes preserve unknown keys, UUIDs and metadata types")
    func preservesOriginalRepresentation() throws {
        let originalData = try SafariPersistenceFixture.data()
        let document = try SafariBookmarkDocument(
            data: originalData,
            sourceFingerprint: SafariPersistenceFixture.placeholderFingerprint
        )
        let root = try #require(PropertyListSerialization.propertyList(
            from: document.data,
            options: [],
            format: nil
        ) as? [String: Any])
        let metadata = try #require(root["UnknownRootMetadata"] as? [String: Any])

        #expect(document.data == originalData)
        #expect(root["WebBookmarkUUID"] as? String == SafariPersistenceFixture.rootUUID)
        #expect(metadata["enabled"] as? Bool == true)
        #expect(metadata["count"] as? Int == 7)
        #expect(metadata["ratio"] as? Double == 1.5)
        #expect(metadata["date"] as? Date == SafariPersistenceFixture.metadataDate)
        #expect(metadata["payload"] as? Data == SafariPersistenceFixture.metadataData)
    }

    @Test("Document is Sendable")
    func strictConcurrency() throws {
        let document = try SafariBookmarkDocument(
            data: SafariPersistenceFixture.data(),
            sourceFingerprint: SafariPersistenceFixture.placeholderFingerprint
        )
        requireSendable(document)
    }

    private func requireSendable<T: Sendable>(_ value: T) { _ = value }
}
