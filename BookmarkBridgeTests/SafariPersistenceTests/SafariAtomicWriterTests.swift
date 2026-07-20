//
//  SafariAtomicWriterTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("Safari atomic writer")
struct SafariAtomicWriterTests {
    @Test("A synchronized temporary file atomically replaces the destination")
    func atomicWrite() throws {
        let directory = try SafariPersistenceFixture.temporaryDirectory()
        let destinationURL = try SafariPersistenceFixture.writeBookmarks(in: directory)
        let fingerprint = try SafariDocumentFingerprint.capture(at: destinationURL)
        let replacementData = try SafariPersistenceFixture.data(format: .xml)

        try SafariAtomicWriter().write(
            replacementData,
            to: destinationURL,
            replacing: fingerprint
        )

        #expect(try Data(contentsOf: destinationURL) == replacementData)
        #expect(try temporaryItems(in: directory).isEmpty)
    }

    @Test("A concurrent modification prevents replacement")
    func concurrentModification() throws {
        let directory = try SafariPersistenceFixture.temporaryDirectory()
        let destinationURL = try SafariPersistenceFixture.writeBookmarks(in: directory)
        let fingerprint = try SafariDocumentFingerprint.capture(at: destinationURL)
        let externallyModifiedData = Data("external change".utf8)
        try externallyModifiedData.write(to: destinationURL)

        #expect(throws: SafariPersistenceError.concurrentModification) {
            try SafariAtomicWriter().write(
                try SafariPersistenceFixture.data(format: .xml),
                to: destinationURL,
                replacing: fingerprint
            )
        }
        #expect(try Data(contentsOf: destinationURL) == externallyModifiedData)
        #expect(try temporaryItems(in: directory).isEmpty)
    }

    @Test("A replacement failure retains the destination and cleans temporary data")
    func replacementFailure() throws {
        let directory = try SafariPersistenceFixture.temporaryDirectory()
        let destinationURL = try SafariPersistenceFixture.writeBookmarks(in: directory)
        let originalData = try Data(contentsOf: destinationURL)
        let fingerprint = try SafariDocumentFingerprint.capture(at: destinationURL)
        let temporaryURL = directory.appendingPathComponent("known.tmp")
        let writer = SafariAtomicWriter(
            temporaryURLProvider: { _ in temporaryURL },
            replace: { _, _ in throw TestAtomicWriterFailure.expected }
        )

        #expect(throws: SafariPersistenceError.atomicReplacementFailed) {
            try writer.write(Data("replacement".utf8), to: destinationURL, replacing: fingerprint)
        }
        #expect(try Data(contentsOf: destinationURL) == originalData)
        #expect(!FileManager().fileExists(atPath: temporaryURL.path(percentEncoded: false)))
    }

    @Test("A temporary-file creation failure is explicit")
    func temporaryWriteFailure() throws {
        let directory = try SafariPersistenceFixture.temporaryDirectory()
        let destinationURL = try SafariPersistenceFixture.writeBookmarks(in: directory)
        let fingerprint = try SafariDocumentFingerprint.capture(at: destinationURL)
        let writer = SafariAtomicWriter(createFile: { _ in false })

        #expect(throws: SafariPersistenceError.temporaryWriteFailed) {
            try writer.write(Data(), to: destinationURL, replacing: fingerprint)
        }
    }

    private func temporaryItems(in directory: URL) throws -> [URL] {
        try FileManager().contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.contains("bookmarkbridge-") }
    }
}

private nonisolated enum TestAtomicWriterFailure: Error {
    case expected
}
