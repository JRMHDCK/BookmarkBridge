//
//  ChromeBookmarkApplier.swift
//  BookmarkBridge
//

import Foundation

/// Errors raised while applying additions to a Chrome bookmark file.
nonisolated enum ChromeWriteError: Error, Equatable {
    /// Chrome is running; writing would race it and is refused.
    case browserIsRunning
    /// The target is the account-bookmarks file (`AccountBookmarks`). V1 writes
    /// only the `Bookmarks` file (`kLocalOrSyncableBookmarksFileName`); writing
    /// the account file is deferred until a reliable path is established.
    case accountBookmarksAreReadOnly
}

/// Applies additive changes to a Chrome `Bookmarks` file **safely**.
///
/// The guarded sequence, every time:
/// 1. refuse if Chrome is running (never race the browser);
/// 2. take a mandatory, timestamped **backup** (so the write is reversible);
/// 3. compute the new JSON from the *current* file (`ChromeBookmarkWriter`);
/// 4. copy the pre-write file to `Bookmarks.bak` (Chrome's own convention +
///    an extra safety net);
/// 5. write the new content **atomically**.
///
/// Pure orchestration over injected collaborators, so it is exercised entirely
/// on temporary files in tests — never a real Chrome profile. Writing a real
/// file additionally requires the read-write file entitlement, enabled only for
/// the actual apply action.
/// Abstraction over the Chrome write sequence, so the sync UI is testable with a
/// double.
nonisolated protocol ChromeBookmarkApplying: Sendable {
    @discardableResult
    func apply(
        _ additions: [Bookmark],
        to location: BrowserLocation,
        in scopeDirectory: BrowserLocation,
        now: Date
    ) async throws -> BackupHandle
}

nonisolated struct ChromeBookmarkApplier: ChromeBookmarkApplying {
    private let detector: any RunningBrowserDetecting
    private let backup: any BookmarkBackup
    private let writer: ChromeBookmarkWriter
    private let fileController: any SecurityScopedFileControlling

    init(
        detector: any RunningBrowserDetecting,
        backup: any BookmarkBackup,
        writer: ChromeBookmarkWriter = ChromeBookmarkWriter(),
        fileController: any SecurityScopedFileControlling = SystemSecurityScopedFileController()
    ) {
        self.detector = detector
        self.backup = backup
        self.writer = writer
        self.fileController = fileController
    }

    /// Adds `additions` to the Chrome file at `location`, returning the backup
    /// handle for the pre-write state. Throws (and writes nothing) if Chrome is
    /// running. `scopeDirectory` is the security-scoped Chrome directory: access
    /// to it is opened for the whole backup + write and released before
    /// returning. `now` stamps the new nodes (injected for tests).
    @discardableResult
    func apply(
        _ additions: [Bookmark],
        to location: BrowserLocation,
        in scopeDirectory: BrowserLocation,
        now: Date
    ) async throws -> BackupHandle {
        guard !detector.isRunning(location.browser) else {
            throw ChromeWriteError.browserIsRunning
        }
        // V1 policy (file-based, no sync-status inference): write only the
        // `Bookmarks` file (`kLocalOrSyncableBookmarksFileName`). The account
        // file (`AccountBookmarks`) is read-only for now.
        guard location.fileURL.lastPathComponent == "Bookmarks" else {
            throw ChromeWriteError.accountBookmarksAreReadOnly
        }

        // Hold security-scoped access to the Chrome directory for the whole
        // backup + write, then release it (the sandbox denies file I/O otherwise).
        let scopeURL = scopeDirectory.fileURL
        let accessing = fileController.startAccessing(scopeURL)
        defer { if accessing { fileController.stopAccessing(scopeURL) } }

        let handle = try await backup.backup(location)

        let original = try Data(contentsOf: location.fileURL)
        let updated = try writer.applying(additions, to: original, now: now)

        // Keep the pre-write file as Bookmarks.bak (Chrome convention + safety).
        let bakURL = location.fileURL.deletingPathExtension().appendingPathExtension("bak")
        try? original.write(to: bakURL, options: [.atomic])

        try updated.write(to: location.fileURL, options: [.atomic])
        return handle
    }
}
