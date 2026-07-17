//
//  ChromeBookmarkApplier.swift
//  BookmarkBridge
//

import Foundation
import OSLog

nonisolated private let chromeWriteLogger = Logger(
    subsystem: "fr.jerome.BookmarkBridge",
    category: "ChromeBookmarkApplier"
)

/// Diagnostic details intentionally surfaced while the real sandbox write
/// failure is being investigated.
nonisolated struct ChromeWriteDiagnostic: Equatable, Sendable {
    let stage: String
    let errorType: String
    let localizedDescription: String
    let domain: String
    let code: Int
    let underlyingError: String?

    init(stage: String, error: any Error) {
        let nsError = error as NSError
        self.stage = stage
        self.errorType = String(reflecting: type(of: error))
        self.localizedDescription = nsError.localizedDescription
        self.domain = nsError.domain
        self.code = nsError.code
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? any Error {
            let underlyingNSError = underlying as NSError
            self.underlyingError = "\(String(reflecting: type(of: underlying))): \(underlyingNSError.localizedDescription) [domain=\(underlyingNSError.domain) code=\(underlyingNSError.code)]"
        } else {
            self.underlyingError = nil
        }
    }

    var consoleDescription: String {
        let underlying = underlyingError.map { " underlying=\($0)" } ?? " underlying=none"
        return "[BookmarkBridge][ChromeBookmarkApplier] stage=\(stage) status=failure type=\(errorType) localizedDescription=\(localizedDescription) domain=\(domain) code=\(code)\(underlying)"
    }

    var interfaceDescription: String {
        var lines = [
            "Étape : \(stage)",
            "Type : \(errorType)",
            "Erreur : \(localizedDescription)",
            "NSError : \(domain) (\(code))",
        ]
        if let underlyingError {
            lines.append("Erreur interne : \(underlyingError)")
        }
        return lines.joined(separator: "\n")
    }
}

/// Errors raised while applying additions to a Chrome bookmark file.
nonisolated enum ChromeWriteError: Error, Equatable {
    /// Chrome is running; writing would race it and is refused.
    case browserIsRunning
    /// Chrome was launched after the transaction began. The target is left
    /// untouched and the pre-write backup remains available.
    case browserStartedDuringTransaction(backup: BackupHandle)
    /// The target is the account-bookmarks file (`AccountBookmarks`). V1 writes
    /// only the `Bookmarks` file (`kLocalOrSyncableBookmarksFileName`); writing
    /// the account file is deferred until a reliable path is established.
    case accountBookmarksAreReadOnly
    /// The mandatory backup succeeded, but reading or generating the updated
    /// file, or replacing the target, failed. The backup remains restorable.
    case transactionFailed(backup: BackupHandle, diagnostic: ChromeWriteDiagnostic)
    /// The mandatory backup succeeded, but Chrome's `Bookmarks.bak` copy could
    /// not be created. The target file is left untouched.
    case bakCreationFailed(backup: BackupHandle, diagnostic: ChromeWriteDiagnostic)
    /// The mandatory backup itself failed, so no restoration handle exists.
    case backupFailed(diagnostic: ChromeWriteDiagnostic)
    /// The authorized Chrome root could not be opened for this profile.
    case securityScopeDenied(diagnostic: ChromeWriteDiagnostic)
}

nonisolated struct ChromeApplyResult: Equatable, Sendable {
    let backup: BackupHandle
    let addedCount: Int
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
    ) async throws -> ChromeApplyResult
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
    ) async throws -> ChromeApplyResult {
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
        let profileURL = location.fileURL.deletingLastPathComponent()
        guard Self.contains(profileURL, in: scopeURL) else {
            let error = NSError(
                domain: NSPOSIXErrorDomain,
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Le profil Chrome n'est pas contenu dans la racine autorisée."]
            )
            let diagnostic = ChromeWriteDiagnostic(stage: "ouverture du security scope", error: error)
            chromeWriteLogger.error("\(diagnostic.consoleDescription, privacy: .public)")
            throw ChromeWriteError.securityScopeDenied(diagnostic: diagnostic)
        }
        chromeWriteLogger.info("[BookmarkBridge][ChromeBookmarkApplier] stage=security-scope status=starting path=\(scopeURL.path, privacy: .public)")
        let accessing = fileController.startAccessing(scopeURL)
        chromeWriteLogger.info("[BookmarkBridge][ChromeBookmarkApplier] stage=security-scope status=opened granted=\(accessing, privacy: .public)")
        guard accessing else {
            let error = NSError(
                domain: NSPOSIXErrorDomain,
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Le security scope Chrome n'autorise pas l'écriture."]
            )
            let diagnostic = ChromeWriteDiagnostic(stage: "ouverture du security scope", error: error)
            chromeWriteLogger.error("\(diagnostic.consoleDescription, privacy: .public)")
            throw ChromeWriteError.securityScopeDenied(diagnostic: diagnostic)
        }
        defer { if accessing { fileController.stopAccessing(scopeURL) } }

        let handle: BackupHandle
        do {
            chromeWriteLogger.info("[BookmarkBridge][ChromeBookmarkApplier] stage=backup status=starting")
            handle = try await backup.backup(location)
            chromeWriteLogger.info("[BookmarkBridge][ChromeBookmarkApplier] stage=backup status=success path=\(handle.fileURL.path, privacy: .public)")
        } catch {
            let diagnostic = ChromeWriteDiagnostic(stage: "sauvegarde", error: error)
            chromeWriteLogger.error("\(diagnostic.consoleDescription, privacy: .public)")
            throw ChromeWriteError.backupFailed(diagnostic: diagnostic)
        }

        let original: Data
        do {
            chromeWriteLogger.info("[BookmarkBridge][ChromeBookmarkApplier] stage=read-current-file status=starting path=\(location.fileURL.path, privacy: .public)")
            original = try Data(contentsOf: location.fileURL)
            chromeWriteLogger.info("[BookmarkBridge][ChromeBookmarkApplier] stage=read-current-file status=success bytes=\(original.count, privacy: .public)")
        } catch {
            let diagnostic = ChromeWriteDiagnostic(stage: "lecture du fichier courant", error: error)
            chromeWriteLogger.error("\(diagnostic.consoleDescription, privacy: .public)")
            throw ChromeWriteError.transactionFailed(backup: handle, diagnostic: diagnostic)
        }

        let updated: Data
        let addedCount: Int
        do {
            chromeWriteLogger.info("[BookmarkBridge][ChromeBookmarkApplier] stage=generation-checksum status=starting additions=\(additions.count, privacy: .public)")
            let currentTree = try ChromeBookmarkDecoder().decodeTree(from: original)
            var seen = Set(currentTree.allBookmarks.map { BookmarkMatchKey.key(for: $0.url) })
            let missingAdditions = additions.filter { bookmark in
                seen.insert(BookmarkMatchKey.key(for: bookmark.url)).inserted
            }
            guard !missingAdditions.isEmpty else {
                chromeWriteLogger.info("[BookmarkBridge][ChromeBookmarkApplier] stage=generation-checksum status=skipped reason=no-missing-additions")
                return ChromeApplyResult(backup: handle, addedCount: 0)
            }
            addedCount = missingAdditions.count
            updated = try writer.applying(missingAdditions, to: original, now: now)
            chromeWriteLogger.info("[BookmarkBridge][ChromeBookmarkApplier] stage=generation-checksum status=success bytes=\(updated.count, privacy: .public) additions=\(missingAdditions.count, privacy: .public)")
        } catch {
            let diagnostic = ChromeWriteDiagnostic(stage: "génération et checksum", error: error)
            chromeWriteLogger.error("\(diagnostic.consoleDescription, privacy: .public)")
            throw ChromeWriteError.transactionFailed(backup: handle, diagnostic: diagnostic)
        }

        // Keep the pre-write file as Bookmarks.bak (Chrome convention + safety).
        let bakURL = location.fileURL.deletingPathExtension().appendingPathExtension("bak")
        do {
            chromeWriteLogger.info("[BookmarkBridge][ChromeBookmarkApplier] stage=create-bookmarks-bak status=starting path=\(bakURL.path, privacy: .public)")
            try Self.atomicallyWriteBackup(original, to: bakURL)
            chromeWriteLogger.info("[BookmarkBridge][ChromeBookmarkApplier] stage=create-bookmarks-bak status=success")
        } catch {
            let diagnostic = ChromeWriteDiagnostic(stage: "création de Bookmarks.bak", error: error)
            chromeWriteLogger.error("\(diagnostic.consoleDescription, privacy: .public)")
            throw ChromeWriteError.bakCreationFailed(backup: handle, diagnostic: diagnostic)
        }

        guard !detector.isRunning(location.browser) else {
            throw ChromeWriteError.browserStartedDuringTransaction(backup: handle)
        }

        do {
            chromeWriteLogger.info("[BookmarkBridge][ChromeBookmarkApplier] stage=atomic-replacement status=starting path=\(location.fileURL.path, privacy: .public)")
            try updated.write(to: location.fileURL, options: [.atomic])
            chromeWriteLogger.info("[BookmarkBridge][ChromeBookmarkApplier] stage=atomic-replacement status=success")
        } catch {
            let diagnostic = ChromeWriteDiagnostic(stage: "remplacement atomique", error: error)
            chromeWriteLogger.error("\(diagnostic.consoleDescription, privacy: .public)")
            throw ChromeWriteError.transactionFailed(backup: handle, diagnostic: diagnostic)
        }
        return ChromeApplyResult(backup: handle, addedCount: addedCount)
    }

    private static func contains(_ child: URL, in root: URL) -> Bool {
        let childComponents = child.standardizedFileURL.pathComponents
        let rootComponents = root.standardizedFileURL.pathComponents
        return childComponents.starts(with: rootComponents)
    }

    /// Stages the bytes beside `Bookmarks.bak`, then commits with a same-volume
    /// move or replacement. Both final operations are atomic and remain inside
    /// the already-open Chrome directory security scope.
    private static func atomicallyWriteBackup(_ data: Data, to destination: URL) throws {
        let fileManager = FileManager.default
        let temporary = destination.deletingLastPathComponent()
            .appendingPathComponent(".Bookmarks.bak.\(UUID().uuidString).tmp", isDirectory: false)
        defer {
            if fileManager.fileExists(atPath: temporary.path) {
                do {
                    try fileManager.removeItem(at: temporary)
                } catch {
                    chromeWriteLogger.error("[BookmarkBridge][ChromeBookmarkApplier] stage=create-bookmarks-bak status=temporary-cleanup-failure localizedDescription=\(error.localizedDescription, privacy: .public)")
                }
            }
        }

        try data.write(to: temporary, options: [.withoutOverwriting])
        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: temporary)
        } else {
            try fileManager.moveItem(at: temporary, to: destination)
        }
    }
}
