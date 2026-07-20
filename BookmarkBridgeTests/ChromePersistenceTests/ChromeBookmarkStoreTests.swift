//
//  ChromeBookmarkStoreTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Synchronization
import Testing
@testable import BookmarkBridge

@Suite("Chrome bookmark store")
struct ChromeBookmarkStoreTests {
    @Test("Loads and validates a controlled Chrome Bookmarks file")
    func load() throws {
        let directory = try ChromePersistenceTestSupport.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let URL = try ChromePersistenceTestSupport.writeBookmarks(in: directory)

        let document = try StoreTestSupport.store(fileURL: URL).load()

        let sourceData = try Data(contentsOf: URL)
        #expect(document.data == sourceData)
        try ChromeBookmarkValidator().validate(document)
    }

    @Test("Default and Profile 1 use the explicit Bookmarks URL identically", arguments: [
        "Default", "Profile 1",
    ])
    func profiles(profileName: String) throws {
        let directory = try ChromePersistenceTestSupport.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let profile = directory.appending(path: profileName, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: profile, withIntermediateDirectories: true)
        let URL = try ChromePersistenceTestSupport.writeBookmarks(in: profile)

        let document = try StoreTestSupport.store(fileURL: URL).load()

        #expect(URL.deletingLastPathComponent().lastPathComponent == profileName)
        #expect(!document.data.isEmpty)
    }

    @Test("Missing and unreadable files have distinct errors")
    func sourceErrors() throws {
        let URL = URL(filePath: "/test-only/Default/Bookmarks")
        let missing = StoreTestSupport.store(
            fileURL: URL,
            fileExists: { _ in false },
            isReadable: { _ in true }
        )
        let denied = StoreTestSupport.store(
            fileURL: URL,
            fileExists: { _ in true },
            isReadable: { _ in false }
        )

        #expect(throws: ChromePersistenceError.fileMissing) { _ = try missing.load() }
        #expect(throws: ChromePersistenceError.accessDenied) { _ = try denied.load() }
    }

    @Test("Malformed JSON is rejected during load")
    func invalidJSON() throws {
        let directory = try ChromePersistenceTestSupport.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let URL = directory.appending(path: "Bookmarks")
        try Data("not-json".utf8).write(to: URL)

        #expect(throws: ChromePersistenceError.invalidJSON) {
            _ = try StoreTestSupport.store(fileURL: URL).load()
        }
    }

    @Test("A modification between the two load fingerprints is rejected")
    func concurrentLoad() throws {
        let data = try ChromePersistenceTestSupport.data()
        let first = ChromePersistenceTestSupport.placeholderFingerprint(for: data)
        let second = ChromeDocumentFingerprint(
            contentDigest: Data(repeating: 0xaa, count: first.contentDigest.count),
            fileSize: first.fileSize,
            modificationDate: first.modificationDate,
            fileSystemNumber: first.fileSystemNumber,
            fileNumber: first.fileNumber
        )
        let fingerprints = Mutex([first, second])
        let store = StoreTestSupport.store(
            fileURL: URL(filePath: "/test-only/Bookmarks"),
            fileExists: { _ in true },
            isReadable: { _ in true },
            readData: { _ in data },
            fingerprintProvider: { _ in fingerprints.withLock { $0.removeFirst() } }
        )

        #expect(throws: ChromePersistenceError.concurrentModification) {
            _ = try store.load()
        }
    }

    @Test("Save creates a faithful backup then writes JSON with a current checksum")
    func save() throws {
        let directory = try ChromePersistenceTestSupport.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let URL = try ChromePersistenceTestSupport.writeBookmarks(in: directory)
        let backupDirectory = directory.appending(path: "Backups", directoryHint: .isDirectory)
        let store = ChromeBookmarkStore(
            bookmarksFileURL: URL,
            validator: ChromeBookmarkValidator(),
            backupService: ChromeBookmarkBackupService(
                backupDirectoryURL: backupDirectory,
                dateProvider: { Date(timeIntervalSince1970: 5) }
            ),
            atomicWriter: ChromeAtomicWriter(),
            applicationStateChecker: ClosedChromeChecker()
        )
        let loaded = try store.load()
        let original = loaded.data
        var object = try ChromePersistenceTestSupport.object(from: loaded.data)
        object["checksum"] = "stale"
        object["new_unknown_metadata"] = ["value": 99]
        let mutatedData = try ChromePersistenceTestSupport.data(object)
        let mutated = try ChromeBookmarkDocument(
            data: mutatedData,
            sourceFingerprint: loaded.sourceFingerprint
        )

        let backup = try store.save(mutated)

        #expect(try Data(contentsOf: backup) == original)
        let persisted = try ChromePersistenceTestSupport.object(from: Data(contentsOf: URL))
        let roots = try #require(persisted["roots"] as? [String: Any])
        #expect(persisted["checksum"] as? String == ChromeChecksum.compute(roots: roots))
        #expect((persisted["new_unknown_metadata"] as? [String: Any])?["value"] as? Int == 99)
    }

    @Test("Open Chrome stops before backup and writing")
    func chromeOpen() throws {
        let setup = try StoreTestSupport.recordingStore(
            checker: ChromeApplicationStateChecker(isChromeRunning: { true })
        )

        #expect(throws: ChromePersistenceError.chromeIsOpen) {
            _ = try setup.store.save(setup.document)
        }
        #expect(setup.recorder.events.isEmpty)
    }

    @Test("Concurrent modification stops before backup")
    func concurrentSave() throws {
        let setup = try StoreTestSupport.recordingStore(fingerprintMatches: false)

        #expect(throws: ChromePersistenceError.concurrentModification) {
            _ = try setup.store.save(setup.document)
        }
        #expect(setup.recorder.events.isEmpty)
    }

    @Test("Backup failure prevents atomic writer invocation")
    func backupFailure() throws {
        let setup = try StoreTestSupport.recordingStore(backupFails: true)

        #expect(throws: ChromePersistenceError.backupFailed) {
            _ = try setup.store.save(setup.document)
        }
        #expect(setup.recorder.events == [.backup])
    }

    @Test("Store and collaborators satisfy Sendable boundaries")
    func strictConcurrency() throws {
        let setup = try StoreTestSupport.recordingStore()
        requireSendable(setup.store)
        requireSendable(ChromeBookmarkValidator())
        requireSendable(ChromeAtomicWriter())
        requireSendable(ChromeBookmarkBackupService(
            backupDirectoryURL: URL(filePath: "/test-only/backups")
        ))
    }

    private func requireSendable<T: Sendable>(_ value: T) { _ = value }
}

private nonisolated enum StoreEvent: Hashable, Sendable {
    case backup
    case write
}

private nonisolated final class StoreRecorder: Sendable {
    private let storage = Mutex<[StoreEvent]>([])
    var events: [StoreEvent] { storage.withLock { $0 } }
    func append(_ event: StoreEvent) { storage.withLock { $0.append(event) } }
}

private nonisolated struct RecordingChromeBackup: ChromeBookmarkBackingUp {
    let recorder: StoreRecorder
    let fails: Bool

    func createBackup(of sourceURL: URL) throws -> URL {
        recorder.append(.backup)
        if fails { throw ChromePersistenceError.backupFailed }
        return URL(filePath: "/test-only/backup")
    }
}

private nonisolated struct RecordingChromeWriter: ChromeAtomicallyWriting {
    let recorder: StoreRecorder

    func write(
        _ data: Data,
        to destinationURL: URL,
        replacing expectedFingerprint: ChromeDocumentFingerprint
    ) throws {
        recorder.append(.write)
    }
}

private nonisolated enum StoreTestSupport {
    struct RecordingSetup {
        let store: ChromeBookmarkStore
        let document: ChromeBookmarkDocument
        let recorder: StoreRecorder
    }

    static func store(
        fileURL: URL,
        fileExists: @escaping @Sendable (URL) -> Bool = {
            FileManager.default.fileExists(atPath: $0.path)
        },
        isReadable: @escaping @Sendable (URL) -> Bool = {
            FileManager.default.isReadableFile(atPath: $0.path)
        },
        readData: @escaping @Sendable (URL) throws -> Data = {
            try Data(contentsOf: $0)
        },
        fingerprintProvider: @escaping @Sendable (URL) throws -> ChromeDocumentFingerprint = {
            try ChromeDocumentFingerprint.capture(at: $0)
        }
    ) -> ChromeBookmarkStore {
        ChromeBookmarkStore(
            bookmarksFileURL: fileURL,
            validator: ChromeBookmarkValidator(),
            backupService: RecordingChromeBackup(recorder: StoreRecorder(), fails: false),
            atomicWriter: RecordingChromeWriter(recorder: StoreRecorder()),
            applicationStateChecker: ClosedChromeChecker(),
            fileExists: fileExists,
            isReadable: isReadable,
            readData: readData,
            fingerprintProvider: fingerprintProvider
        )
    }

    static func recordingStore(
        checker: any ChromeApplicationStateChecking = ClosedChromeChecker(),
        fingerprintMatches: Bool = true,
        backupFails: Bool = false
    ) throws -> RecordingSetup {
        let document = try ChromePersistenceTestSupport.document()
        let recorder = StoreRecorder()
        let fingerprint = fingerprintMatches
            ? document.sourceFingerprint
            : ChromeDocumentFingerprint(
                contentDigest: Data(repeating: 0xbb, count: 32),
                fileSize: document.sourceFingerprint.fileSize,
                modificationDate: document.sourceFingerprint.modificationDate,
                fileSystemNumber: document.sourceFingerprint.fileSystemNumber,
                fileNumber: document.sourceFingerprint.fileNumber
            )
        return RecordingSetup(
            store: ChromeBookmarkStore(
                bookmarksFileURL: URL(filePath: "/test-only/Bookmarks"),
                validator: ChromeBookmarkValidator(),
                backupService: RecordingChromeBackup(
                    recorder: recorder,
                    fails: backupFails
                ),
                atomicWriter: RecordingChromeWriter(recorder: recorder),
                applicationStateChecker: checker,
                fileExists: { _ in true },
                isReadable: { _ in true },
                readData: { _ in document.data },
                fingerprintProvider: { _ in fingerprint }
            ),
            document: document,
            recorder: recorder
        )
    }
}
