//
//  ChromeAtomicWriterTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Synchronization
import Testing
@testable import BookmarkBridge

@Suite("Chrome atomic writer")
struct ChromeAtomicWriterTests {
    @Test("Default writer stages, synchronizes and atomically replaces")
    func atomicWrite() throws {
        let directory = try ChromePersistenceTestSupport.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = try ChromePersistenceTestSupport.writeBookmarks(in: directory)
        let fingerprint = try ChromeDocumentFingerprint.capture(at: destination)
        let replacement = try ChromePersistenceTestSupport.data([
            "roots": [:], "marker": "replacement",
        ])

        try ChromeAtomicWriter().write(
            replacement,
            to: destination,
            replacing: fingerprint
        )

        #expect(try Data(contentsOf: destination) == replacement)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .allSatisfy { !$0.hasSuffix(".tmp") })
    }

    @Test("Synchronization is invoked after temporary writing and before replacement")
    func synchronizationOrder() throws {
        let directory = try ChromePersistenceTestSupport.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = try ChromePersistenceTestSupport.writeBookmarks(in: directory)
        let temporary = directory.appending(path: ".Bookmarks.test.tmp")
        let fingerprint = try ChromeDocumentFingerprint.capture(at: destination)
        let events = Mutex<[String]>([])
        let writer = ChromeAtomicWriter(
            writeTemporaryFile: { data, URL in
                events.withLock { $0.append("write") }
                try data.write(to: URL, options: [.withoutOverwriting])
            },
            synchronizeTemporaryFile: { _ in
                events.withLock { $0.append("synchronize") }
            },
            temporaryURLProvider: { _ in temporary },
            fingerprintProvider: { _ in fingerprint },
            replace: { destination, temporary in
                events.withLock { $0.append("replace") }
                try FileManager.default.removeItem(at: destination)
                try FileManager.default.moveItem(at: temporary, to: destination)
            }
        )

        try writer.write(Data("replacement".utf8), to: destination, replacing: fingerprint)

        #expect(events.withLock { $0 } == ["write", "synchronize", "replace"])
    }

    @Test("Temporary write failure is explicit")
    func temporaryWriteFailure() throws {
        let directory = try ChromePersistenceTestSupport.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = try ChromePersistenceTestSupport.writeBookmarks(in: directory)
        let fingerprint = try ChromeDocumentFingerprint.capture(at: destination)
        let writer = ChromeAtomicWriter(
            writeTemporaryFile: { _, _ in throw CocoaError(.fileWriteUnknown) }
        )

        #expect(throws: ChromePersistenceError.temporaryWriteFailed) {
            try writer.write(Data(), to: destination, replacing: fingerprint)
        }
    }

    @Test("Synchronization failure is explicit and cleans the temporary file")
    func synchronizationFailure() throws {
        let directory = try ChromePersistenceTestSupport.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = try ChromePersistenceTestSupport.writeBookmarks(in: directory)
        let temporary = directory.appending(path: ".Bookmarks.sync.tmp")
        let fingerprint = try ChromeDocumentFingerprint.capture(at: destination)
        let writer = ChromeAtomicWriter(
            synchronizeTemporaryFile: { _ in throw CocoaError(.fileWriteUnknown) },
            temporaryURLProvider: { _ in temporary }
        )

        #expect(throws: ChromePersistenceError.synchronizationFailed) {
            try writer.write(Data("new".utf8), to: destination, replacing: fingerprint)
        }
        #expect(!FileManager.default.fileExists(atPath: temporary.path))
    }

    @Test("Concurrent source modification prevents replacement")
    func concurrentModification() throws {
        let directory = try ChromePersistenceTestSupport.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = try ChromePersistenceTestSupport.writeBookmarks(in: directory)
        let original = try Data(contentsOf: destination)
        let expected = try ChromeDocumentFingerprint.capture(at: destination)
        let changed = ChromeDocumentFingerprint(
            contentDigest: Data(repeating: 0xff, count: expected.contentDigest.count),
            fileSize: expected.fileSize,
            modificationDate: expected.modificationDate,
            fileSystemNumber: expected.fileSystemNumber,
            fileNumber: expected.fileNumber
        )
        let writer = ChromeAtomicWriter(fingerprintProvider: { _ in changed })

        #expect(throws: ChromePersistenceError.concurrentModification) {
            try writer.write(Data("new".utf8), to: destination, replacing: expected)
        }
        #expect(try Data(contentsOf: destination) == original)
    }

    @Test("Replacement failure is explicit and cleans the temporary file")
    func replacementFailure() throws {
        let directory = try ChromePersistenceTestSupport.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = try ChromePersistenceTestSupport.writeBookmarks(in: directory)
        let temporary = directory.appending(path: ".Bookmarks.replace.tmp")
        let fingerprint = try ChromeDocumentFingerprint.capture(at: destination)
        let writer = ChromeAtomicWriter(
            temporaryURLProvider: { _ in temporary },
            fingerprintProvider: { _ in fingerprint },
            replace: { _, _ in throw CocoaError(.fileWriteUnknown) }
        )

        #expect(throws: ChromePersistenceError.atomicReplacementFailed) {
            try writer.write(Data("new".utf8), to: destination, replacing: fingerprint)
        }
        #expect(!FileManager.default.fileExists(atPath: temporary.path))
    }
}
