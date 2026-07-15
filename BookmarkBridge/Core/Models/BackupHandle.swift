//
//  BackupHandle.swift
//  BookmarkBridge
//

import Foundation

/// A reference to a saved copy of a browser's bookmarks, taken before any write.
///
/// Backups are mandatory before writing (phase 2) and make every operation
/// reversible via `BookmarkBackup.restore(_:)`.
nonisolated struct BackupHandle: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    let browser: Browser
    let createdAt: Date
    let fileURL: URL

    init(id: UUID, browser: Browser, createdAt: Date, fileURL: URL) {
        self.id = id
        self.browser = browser
        self.createdAt = createdAt
        self.fileURL = fileURL
    }
}
