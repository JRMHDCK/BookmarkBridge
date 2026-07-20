//
//  SafariDocumentFingerprintTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("Safari document fingerprint")
struct SafariDocumentFingerprintTests {
    @Test("An unchanged file has an identical fingerprint")
    func identicalFingerprint() throws {
        let directory = try SafariPersistenceFixture.temporaryDirectory()
        let fileURL = try SafariPersistenceFixture.writeBookmarks(in: directory)

        #expect(
            try SafariDocumentFingerprint.capture(at: fileURL)
                == SafariDocumentFingerprint.capture(at: fileURL)
        )
    }

    @Test("Content changes alter the fingerprint even at the same path")
    func modifiedFingerprint() throws {
        let directory = try SafariPersistenceFixture.temporaryDirectory()
        let fileURL = try SafariPersistenceFixture.writeBookmarks(in: directory)
        let before = try SafariDocumentFingerprint.capture(at: fileURL)
        try Data("different bytes".utf8).write(to: fileURL)
        let after = try SafariDocumentFingerprint.capture(at: fileURL)

        #expect(before != after)
        #expect(before.contentDigest != after.contentDigest)
    }

    @Test("A missing file has an explicit error")
    func missingFile() throws {
        let directory = try SafariPersistenceFixture.temporaryDirectory()
        let missingURL = directory.appendingPathComponent("Bookmarks.plist")

        #expect(throws: SafariPersistenceError.fileMissing) {
            _ = try SafariDocumentFingerprint.capture(at: missingURL)
        }
    }
}
