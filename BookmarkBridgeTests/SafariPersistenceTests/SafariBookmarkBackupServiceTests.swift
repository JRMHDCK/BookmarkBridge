//
//  SafariBookmarkBackupServiceTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("Safari bookmark backup service")
struct SafariBookmarkBackupServiceTests {
    private let timestamp = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("Backup copies the complete original file")
    func backup() throws {
        let directory = try SafariPersistenceFixture.temporaryDirectory()
        let sourceURL = try SafariPersistenceFixture.writeBookmarks(in: directory)
        let backupDirectory = directory.appendingPathComponent("Backups", isDirectory: true)
        let service = SafariBookmarkBackupService(
            backupDirectoryURL: backupDirectory,
            dateProvider: { timestamp }
        )

        let backupURL = try service.createBackup(of: sourceURL)

        #expect(FileManager().fileExists(atPath: backupURL.path(percentEncoded: false)))
        #expect(try Data(contentsOf: backupURL) == Data(contentsOf: sourceURL))
        #expect(backupURL.lastPathComponent.contains("1700000000000000"))
    }

    @Test("An existing backup is never overwritten")
    func refusesOverwrite() throws {
        let directory = try SafariPersistenceFixture.temporaryDirectory()
        let sourceURL = try SafariPersistenceFixture.writeBookmarks(in: directory)
        let service = SafariBookmarkBackupService(
            backupDirectoryURL: directory.appendingPathComponent("Backups"),
            dateProvider: { timestamp }
        )
        let firstURL = try service.createBackup(of: sourceURL)
        let firstData = try Data(contentsOf: firstURL)

        #expect(throws: SafariPersistenceError.backupFailed) {
            _ = try service.createBackup(of: sourceURL)
        }
        #expect(try Data(contentsOf: firstURL) == firstData)
    }

    @Test("A copy failure is explicit")
    func copyFailure() throws {
        let directory = try SafariPersistenceFixture.temporaryDirectory()
        let sourceURL = try SafariPersistenceFixture.writeBookmarks(in: directory)
        let service = SafariBookmarkBackupService(
            backupDirectoryURL: directory.appendingPathComponent("Backups"),
            copyItem: { _, _ in throw TestFailure.expected }
        )

        #expect(throws: SafariPersistenceError.backupFailed) {
            _ = try service.createBackup(of: sourceURL)
        }
    }
}

private nonisolated enum TestFailure: Error {
    case expected
}
