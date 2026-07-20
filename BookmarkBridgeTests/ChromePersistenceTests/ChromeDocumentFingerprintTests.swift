//
//  ChromeDocumentFingerprintTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("Chrome document fingerprint")
struct ChromeDocumentFingerprintTests {
    @Test("An unchanged file produces the same robust fingerprint")
    func stableFingerprint() throws {
        let directory = try ChromePersistenceTestSupport.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let URL = try ChromePersistenceTestSupport.writeBookmarks(in: directory)

        let first = try ChromeDocumentFingerprint.capture(at: URL)
        let second = try ChromeDocumentFingerprint.capture(at: URL)

        #expect(first == second)
        #expect(first.fileSize > 0)
        #expect(!first.contentDigest.isEmpty)
        #expect(first.fileSystemNumber > 0)
        #expect(first.fileNumber > 0)
    }

    @Test("Changed content changes the fingerprint even at the same URL")
    func modifiedFingerprint() throws {
        let directory = try ChromePersistenceTestSupport.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let URL = try ChromePersistenceTestSupport.writeBookmarks(in: directory)
        let before = try ChromeDocumentFingerprint.capture(at: URL)

        try Data("{\"roots\":{}}".utf8).write(to: URL)
        let after = try ChromeDocumentFingerprint.capture(at: URL)

        #expect(before != after)
        #expect(before.contentDigest != after.contentDigest)
    }
}
