//
//  InMemoryBackupStore.swift
//  BookmarkBridge
//

import Foundation

/// A `BookmarkBackup` double that records handles in memory.
///
/// An `actor` because it holds mutable state accessed concurrently. It performs
/// no real file copy — it exists to complete the object graph and to back
/// previews/tests during the architecture phase. `restore(_:)` is a no-op.
actor InMemoryBackupStore: BookmarkBackup {
    private var handles: [BackupHandle] = []

    func backup(_ location: BrowserLocation) async throws -> BackupHandle {
        let handle = BackupHandle(
            id: UUID(),
            browser: location.browser,
            createdAt: Date(),
            fileURL: location.fileURL
        )
        handles.append(handle)
        return handle
    }

    func restore(_ handle: BackupHandle) async throws {
        // In-memory double: there is nothing to restore.
    }

    func backups(for browser: Browser) async throws -> [BackupHandle] {
        handles
            .filter { $0.browser == browser }
            .sorted { $0.createdAt > $1.createdAt }
    }
}
