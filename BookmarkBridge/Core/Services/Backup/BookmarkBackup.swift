//
//  BookmarkBackup.swift
//  BookmarkBridge
//

import Foundation

/// Creates and restores timestamped backups of a browser's bookmarks.
///
/// A backup is required before any write (phase 2) so that every operation is
/// reversible. Reading a source and copying it to a backup are safe,
/// non-destructive operations, so this protocol exists in the read-only phase.
nonisolated protocol BookmarkBackup: Sendable {
    /// Copies the bookmarks at `location` to a safe, timestamped backup.
    func backup(_ location: BrowserLocation) async throws -> BackupHandle

    /// Restores a previously created backup, overwriting current bookmarks.
    func restore(_ handle: BackupHandle) async throws

    /// Lists available backups for a browser, newest first.
    func backups(for browser: Browser) async throws -> [BackupHandle]

    /// Lists available backups for one exact bookmark file, newest first.
    func backups(for location: BrowserLocation) async throws -> [BackupHandle]
}
