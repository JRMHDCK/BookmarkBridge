//
//  FileBookmarkBackupTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("FileBookmarkBackup")
struct FileBookmarkBackupTests {

    /// A unique temporary root per test — never touches real bookmarks.
    private func makeRoot() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BackupTests-\(UUID().uuidString)", isDirectory: true)
        return url
    }

    private func writeFile(_ contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("orig-\(UUID().uuidString).bin", isDirectory: false)
        try Data(contents.utf8).write(to: url)
        return url
    }

    @Test("Backup copies the file byte-for-byte and records the handle")
    func backupCreatesCopy() async throws {
        let backup = FileBookmarkBackup(rootDirectory: makeRoot())
        let original = try writeFile("SAFARI-BOOKMARKS-V1")
        let location = BrowserLocation(browser: .safari, fileURL: original)

        let handle = try await backup.backup(location)

        #expect(handle.browser == .safari)
        #expect(FileManager.default.fileExists(atPath: handle.fileURL.path))
        #expect(try Data(contentsOf: handle.fileURL) == Data("SAFARI-BOOKMARKS-V1".utf8))
    }

    @Test("Lists backups for a browser, newest first, isolated per browser")
    func listsNewestFirstPerBrowser() async throws {
        let backup = FileBookmarkBackup(rootDirectory: makeRoot())
        let safari = try writeFile("s")
        let chrome = try writeFile("c")

        let first = try await backup.backup(BrowserLocation(browser: .safari, fileURL: safari))
        let second = try await backup.backup(BrowserLocation(browser: .safari, fileURL: safari))
        _ = try await backup.backup(BrowserLocation(browser: .chrome, fileURL: chrome))

        let safariBackups = try await backup.backups(for: .safari)
        #expect(safariBackups.count == 2)
        #expect(Set(safariBackups.map(\.id)) == [first.id, second.id])
        // Newest first (createdAt descending).
        #expect(safariBackups.first!.createdAt >= safariBackups.last!.createdAt)

        #expect(try await backup.backups(for: .chrome).count == 1)
    }

    @Test("Restore rewrites the original file from the backup")
    func restoreRewritesOriginal() async throws {
        let backup = FileBookmarkBackup(rootDirectory: makeRoot())
        let original = try writeFile("ORIGINAL")
        let handle = try await backup.backup(BrowserLocation(browser: .chrome, fileURL: original))

        // Simulate a later (bad) write to the original, then undo it.
        try Data("CORRUPTED".utf8).write(to: original)
        try await backup.restore(handle)

        #expect(try Data(contentsOf: original) == Data("ORIGINAL".utf8))
    }

    @Test("Lists only backups matching the exact bookmark file")
    func listsBackupsForExactLocation() async throws {
        let root = makeRoot()
        let backup = FileBookmarkBackup(rootDirectory: root)
        let firstProfile = try writeFile("first")
        let secondProfile = try writeFile("second")
        let firstLocation = BrowserLocation(browser: .chrome, fileURL: firstProfile)
        let secondLocation = BrowserLocation(browser: .chrome, fileURL: secondProfile)
        let firstHandle = try await backup.backup(firstLocation)
        _ = try await backup.backup(secondLocation)

        let reopenedBackupStore = FileBookmarkBackup(rootDirectory: root)
        let matching = try await reopenedBackupStore.backups(for: firstLocation)

        #expect(matching.map(\.id) == [firstHandle.id])
    }

    @Test("Restoring an unknown handle throws")
    func restoreUnknownThrows() async throws {
        let backup = FileBookmarkBackup(rootDirectory: makeRoot())
        let ghost = BackupHandle(
            id: UUID(),
            browser: .safari,
            createdAt: Date(),
            fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("nope.backup")
        )
        await #expect(throws: BackupError.backupNotFound) {
            try await backup.restore(ghost)
        }
    }
}
