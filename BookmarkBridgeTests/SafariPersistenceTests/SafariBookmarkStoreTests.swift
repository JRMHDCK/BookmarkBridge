//
//  SafariBookmarkStoreTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("Safari bookmark store")
struct SafariBookmarkStoreTests {
    @Test("Load returns a validated coherent document")
    func load() throws {
        let setup = try makeSetup()
        let originalData = try Data(contentsOf: setup.fileURL)

        let document = try setup.store.load()
        let currentFingerprint = try SafariDocumentFingerprint.capture(at: setup.fileURL)

        #expect(document.data == originalData)
        #expect(document.sourceFingerprint == currentFingerprint)
    }

    @Test("Load rejects invalid plist data")
    func invalidPlist() throws {
        let directory = try SafariPersistenceFixture.temporaryDirectory()
        let fileURL = try SafariPersistenceFixture.writeBookmarks(
            in: directory,
            data: Data([0xFF, 0x00, 0xFE])
        )
        let store = makeStore(fileURL: fileURL, backupDirectory: directory)

        #expect(throws: SafariPersistenceError.invalidPropertyList) {
            _ = try store.load()
        }
    }

    @Test("Load rejects a structurally invalid document")
    func invalidStructure() throws {
        var root = SafariPersistenceFixture.propertyList()
        root["Children"] = "invalid"
        let directory = try SafariPersistenceFixture.temporaryDirectory()
        let fileURL = try SafariPersistenceFixture.writeBookmarks(
            in: directory,
            data: SafariPersistenceFixture.data(from: root)
        )
        let store = makeStore(fileURL: fileURL, backupDirectory: directory)

        #expect(throws: SafariPersistenceError.invalidStructure(.invalidChildren(path: []))) {
            _ = try store.load()
        }
    }

    @Test("A missing file is explicit")
    func missingFile() throws {
        let directory = try SafariPersistenceFixture.temporaryDirectory()
        let fileURL = directory.appendingPathComponent("Bookmarks.plist")
        let store = makeStore(fileURL: fileURL, backupDirectory: directory)

        #expect(throws: SafariPersistenceError.fileMissing) {
            _ = try store.load()
        }
    }

    @Test("A read permission failure is explicit")
    func accessDenied() throws {
        let setup = try makeSetup(isReadable: { _ in false })

        #expect(throws: SafariPersistenceError.accessDenied) {
            _ = try setup.store.load()
        }
    }

    @Test("Save creates a mandatory backup before atomic persistence")
    func saveWithBackup() throws {
        let setup = try makeSetup()
        let document = try setup.store.load()

        let backupURL = try setup.store.save(document)

        #expect(FileManager().fileExists(atPath: backupURL.path(percentEncoded: false)))
        #expect(try Data(contentsOf: backupURL) == document.data)
        #expect(try Data(contentsOf: setup.fileURL) == document.data)
    }

    @Test("Safari being open prevents backup and write")
    func safariOpen() throws {
        let directory = try SafariPersistenceFixture.temporaryDirectory()
        let fileURL = try SafariPersistenceFixture.writeBookmarks(in: directory)
        let backup = RecordingBackupService()
        let writer = RecordingAtomicWriter()
        let store = SafariBookmarkStore(
            bookmarksFileURL: fileURL,
            validator: SafariBookmarkValidator(),
            backupService: backup,
            atomicWriter: writer,
            applicationStateChecker: SafariApplicationStateChecker(isSafariRunning: { true })
        )
        let document = try SafariPersistenceFixture.document(at: fileURL)

        #expect(throws: SafariPersistenceError.safariIsOpen) {
            _ = try store.save(document)
        }
        #expect(backup.invocationCount == 0)
        #expect(writer.invocationCount == 0)
    }

    @Test("A backup failure prevents the writer")
    func backupFailure() throws {
        let directory = try SafariPersistenceFixture.temporaryDirectory()
        let fileURL = try SafariPersistenceFixture.writeBookmarks(in: directory)
        let writer = RecordingAtomicWriter()
        let store = SafariBookmarkStore(
            bookmarksFileURL: fileURL,
            validator: SafariBookmarkValidator(),
            backupService: FailingBackupService(),
            atomicWriter: writer,
            applicationStateChecker: SafariApplicationStateChecker(isSafariRunning: { false })
        )
        let document = try SafariPersistenceFixture.document(at: fileURL)

        #expect(throws: SafariPersistenceError.backupFailed) {
            _ = try store.save(document)
        }
        #expect(writer.invocationCount == 0)
    }

    @Test("A changed source is rejected before backup")
    func concurrentModification() throws {
        let directory = try SafariPersistenceFixture.temporaryDirectory()
        let fileURL = try SafariPersistenceFixture.writeBookmarks(in: directory)
        let document = try SafariPersistenceFixture.document(at: fileURL)
        let backup = RecordingBackupService()
        let store = SafariBookmarkStore(
            bookmarksFileURL: fileURL,
            validator: SafariBookmarkValidator(),
            backupService: backup,
            atomicWriter: RecordingAtomicWriter(),
            applicationStateChecker: SafariApplicationStateChecker(isSafariRunning: { false })
        )
        try Data("external".utf8).write(to: fileURL)

        #expect(throws: SafariPersistenceError.concurrentModification) {
            _ = try store.save(document)
        }
        #expect(backup.invocationCount == 0)
    }

    @Test("Store and dependencies satisfy Sendable contracts")
    func strictConcurrency() throws {
        let setup = try makeSetup()
        requireSendable(setup.store)
    }

    private func makeSetup(
        isReadable: @escaping @Sendable (URL) -> Bool = { _ in true }
    ) throws -> (store: SafariBookmarkStore, fileURL: URL) {
        let directory = try SafariPersistenceFixture.temporaryDirectory()
        let fileURL = try SafariPersistenceFixture.writeBookmarks(in: directory)
        return (
            makeStore(
                fileURL: fileURL,
                backupDirectory: directory.appendingPathComponent("Backups"),
                isReadable: isReadable
            ),
            fileURL
        )
    }

    private func makeStore(
        fileURL: URL,
        backupDirectory: URL,
        isReadable: @escaping @Sendable (URL) -> Bool = {
            FileManager().isReadableFile(atPath: $0.path(percentEncoded: false))
        }
    ) -> SafariBookmarkStore {
        SafariBookmarkStore(
            bookmarksFileURL: fileURL,
            validator: SafariBookmarkValidator(),
            backupService: SafariBookmarkBackupService(
                backupDirectoryURL: backupDirectory,
                dateProvider: { Date(timeIntervalSince1970: 1_700_000_000) }
            ),
            atomicWriter: SafariAtomicWriter(),
            applicationStateChecker: SafariApplicationStateChecker(isSafariRunning: { false }),
            isReadable: isReadable
        )
    }

    private func requireSendable<T: Sendable>(_ value: T) { _ = value }
}

private final class InvocationCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func increment() {
        lock.withLock { count += 1 }
    }

    var value: Int {
        lock.withLock { count }
    }
}

private nonisolated struct RecordingBackupService: SafariBookmarkBackingUp {
    private let counter = InvocationCounter()
    var invocationCount: Int { counter.value }

    func createBackup(of sourceURL: URL) throws -> URL {
        counter.increment()
        return sourceURL.appendingPathExtension("backup")
    }
}

private nonisolated struct FailingBackupService: SafariBookmarkBackingUp {
    func createBackup(of sourceURL: URL) throws -> URL {
        throw SafariPersistenceError.backupFailed
    }
}

private nonisolated struct RecordingAtomicWriter: SafariAtomicallyWriting {
    private let counter = InvocationCounter()
    var invocationCount: Int { counter.value }

    func write(
        _ data: Data,
        to destinationURL: URL,
        replacing expectedFingerprint: SafariDocumentFingerprint
    ) throws {
        counter.increment()
    }
}
