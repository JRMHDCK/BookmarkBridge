//
//  ChromeBookmarkBackupServiceTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("Chrome bookmark backup service")
struct ChromeBookmarkBackupServiceTests {
    @Test("Backup is a faithful timestamped copy")
    func backup() throws {
        let directory = try ChromePersistenceTestSupport.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = try ChromePersistenceTestSupport.writeBookmarks(in: directory)
        let backupDirectory = directory.appending(path: "Backups", directoryHint: .isDirectory)
        let service = ChromeBookmarkBackupService(
            backupDirectoryURL: backupDirectory,
            dateProvider: { Date(timeIntervalSince1970: 1.234567) }
        )

        let backup = try service.createBackup(of: source)

        #expect(backup.lastPathComponent == "Bookmarks-1234567.json.backup")
        #expect(try Data(contentsOf: backup) == Data(contentsOf: source))
    }

    @Test("An existing deterministic destination is a typed collision")
    func collision() throws {
        let directory = try ChromePersistenceTestSupport.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = try ChromePersistenceTestSupport.writeBookmarks(in: directory)
        let backupDirectory = directory.appending(path: "Backups", directoryHint: .isDirectory)
        let service = ChromeBookmarkBackupService(
            backupDirectoryURL: backupDirectory,
            dateProvider: { Date(timeIntervalSince1970: 2) }
        )
        _ = try service.createBackup(of: source)

        #expect(throws: ChromePersistenceError.backupCollision) {
            _ = try service.createBackup(of: source)
        }
    }

    @Test("A copy failure prevents backup completion")
    func failure() throws {
        let directory = try ChromePersistenceTestSupport.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = try ChromePersistenceTestSupport.writeBookmarks(in: directory)
        let service = ChromeBookmarkBackupService(
            backupDirectoryURL: directory.appending(path: "Backups"),
            fileExists: { $0 == source },
            createDirectory: { _ in },
            copyItem: { _, _ in throw CocoaError(.fileWriteUnknown) }
        )

        #expect(throws: ChromePersistenceError.backupFailed) {
            _ = try service.createBackup(of: source)
        }
    }
}
