//
//  ChromeBookmarkBackupService.swift
//  BookmarkBridge
//

import Foundation

nonisolated protocol ChromeBookmarkBackingUp: Sendable {
    func createBackup(of sourceURL: URL) throws -> URL
}

/// Creates a timestamped, non-overwriting copy before any replacement.
nonisolated struct ChromeBookmarkBackupService: ChromeBookmarkBackingUp {
    private let backupDirectoryURL: URL
    private let dateProvider: @Sendable () -> Date
    private let fileExists: @Sendable (URL) -> Bool
    private let createDirectory: @Sendable (URL) throws -> Void
    private let copyItem: @Sendable (URL, URL) throws -> Void

    init(
        backupDirectoryURL: URL,
        dateProvider: @escaping @Sendable () -> Date = Date.init,
        fileExists: @escaping @Sendable (URL) -> Bool = {
            FileManager().fileExists(atPath: $0.path(percentEncoded: false))
        },
        createDirectory: @escaping @Sendable (URL) throws -> Void = {
            try FileManager().createDirectory(at: $0, withIntermediateDirectories: true)
        },
        copyItem: @escaping @Sendable (URL, URL) throws -> Void = {
            try FileManager().copyItem(at: $0, to: $1)
        }
    ) {
        self.backupDirectoryURL = backupDirectoryURL
        self.dateProvider = dateProvider
        self.fileExists = fileExists
        self.createDirectory = createDirectory
        self.copyItem = copyItem
    }

    func createBackup(of sourceURL: URL) throws -> URL {
        guard fileExists(sourceURL) else {
            throw ChromePersistenceError.fileMissing
        }
        do {
            try createDirectory(backupDirectoryURL)
        } catch {
            throw ChromePersistenceError.backupFailed
        }

        let timestamp = Int64(dateProvider().timeIntervalSince1970 * 1_000_000)
        let backupURL = backupDirectoryURL.appendingPathComponent(
            "Bookmarks-\(timestamp).json.backup",
            isDirectory: false
        )
        guard !fileExists(backupURL) else {
            throw ChromePersistenceError.backupCollision
        }

        do {
            try copyItem(sourceURL, backupURL)
        } catch let error as CocoaError where error.code == .fileReadNoPermission {
            throw ChromePersistenceError.accessDenied
        } catch {
            throw ChromePersistenceError.backupFailed
        }
        return backupURL
    }
}
