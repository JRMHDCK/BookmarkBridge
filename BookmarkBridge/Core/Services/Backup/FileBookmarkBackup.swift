//
//  FileBookmarkBackup.swift
//  BookmarkBridge
//

import Foundation

/// Errors raised while backing up or restoring bookmark files.
nonisolated enum BackupError: Error, Equatable {
    /// No backup metadata was found for the given handle.
    case backupNotFound
}

/// The real `BookmarkBackup`: copies a browser's bookmark file to a timestamped,
/// private backup on disk, and can restore it.
///
/// Backing up is **non-destructive** (it only ever writes copies under its own
/// backups directory). `restore(_:)` rewrites the *original* location — a write,
/// used to undo a sync — so in production it runs only within the guarded write
/// phase; in tests it targets temporary files exclusively.
///
/// Each backup stores a small JSON sidecar recording the handle and the original
/// path, so a restore knows where to put the bytes back.
nonisolated struct FileBookmarkBackup: BookmarkBackup {

    private let rootDirectory: URL

    init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
    }

    // MARK: - Metadata

    private struct Record: Codable {
        let handle: BackupHandle
        let originalURL: URL
    }

    private func directory(for browser: Browser) -> URL {
        rootDirectory.appendingPathComponent(browser.rawValue, isDirectory: true)
    }

    // MARK: - BookmarkBackup

    func backup(_ location: BrowserLocation) async throws -> BackupHandle {
        let directory = directory(for: location.browser)
        try createDirectory(directory)

        let id = UUID()
        let handle = BackupHandle(
            id: id,
            browser: location.browser,
            createdAt: Date(),
            fileURL: directory.appendingPathComponent("\(id.uuidString).backup", isDirectory: false)
        )

        // Copy the bytes to the backup file (private, atomic).
        let data = try Data(contentsOf: location.fileURL)
        try data.write(to: handle.fileURL, options: [.atomic])
        try setFilePermissions(handle.fileURL)

        // Sidecar metadata so a restore knows the original destination.
        let record = Record(handle: handle, originalURL: location.fileURL)
        let metadataURL = directory.appendingPathComponent("\(id.uuidString).json", isDirectory: false)
        try JSONEncoder().encode(record).write(to: metadataURL, options: [.atomic])
        try setFilePermissions(metadataURL)

        return handle
    }

    func restore(_ handle: BackupHandle) async throws {
        let metadataURL = directory(for: handle.browser)
            .appendingPathComponent("\(handle.id.uuidString).json", isDirectory: false)
        guard let metadata = try? Data(contentsOf: metadataURL),
              let record = try? JSONDecoder().decode(Record.self, from: metadata) else {
            throw BackupError.backupNotFound
        }
        let data = try Data(contentsOf: record.handle.fileURL)
        try data.write(to: record.originalURL, options: [.atomic])
    }

    func backups(for browser: Browser) async throws -> [BackupHandle] {
        let directory = directory(for: browser)
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []

        let decoder = JSONDecoder()
        let handles = contents
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> BackupHandle? in
                guard let data = try? Data(contentsOf: url),
                      let record = try? decoder.decode(Record.self, from: data) else { return nil }
                return record.handle
            }
        return handles.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Filesystem helpers

    private func createDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    }

    private func setFilePermissions(_ url: URL) throws {
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
