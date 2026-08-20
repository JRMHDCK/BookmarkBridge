//
//  DiagnosticFileFingerprintTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("Diagnostic file fingerprint")
struct DiagnosticFileFingerprintTests {
    @Test("Captures stable content and file identity evidence")
    func capturesStableEvidence() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: fileURL) }
        try Data("first".utf8).write(to: fileURL)

        let first = try DiagnosticFileFingerprint.capture(at: fileURL)
        let second = try DiagnosticFileFingerprint.capture(at: fileURL)

        #expect(first == second)
        #expect(first.fileSize == 5)
        #expect(first.contentDigest.count == 32)
        #expect(first.fileSystemNumber > 0)
        #expect(first.fileNumber > 0)
    }

    @Test("Detects a content change")
    func detectsContentChange() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: fileURL) }
        try Data("first".utf8).write(to: fileURL)
        let before = try DiagnosticFileFingerprint.capture(at: fileURL)
        try Data("second".utf8).write(to: fileURL)

        let after = try DiagnosticFileFingerprint.capture(at: fileURL)

        #expect(after.contentDigest != before.contentDigest)
        #expect(after.fileSize != before.fileSize)
    }
}
