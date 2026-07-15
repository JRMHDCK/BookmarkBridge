//
//  AppDependencies.swift
//  BookmarkBridge
//

import Foundation

/// The composition root's dependency graph.
///
/// Holds the concrete services the app runs against, all behind `Core` protocols
/// so that features depend on abstractions, never implementations. It is
/// assembled once and injected downward.
///
/// Safari is wired to the **real** read-only chain (authorized source locator →
/// sandbox file access → reader → decoder). On first launch, before the user has
/// authorized access, reading yields `BookmarkError.authorizationRequired`; the
/// authorization action itself is wired at the app layer (macOS). Diff and backup
/// remain in-memory doubles — those features are not implemented yet.
nonisolated struct AppDependencies {
    let bookmarkReaders: [BookmarkReading]
    let differ: BookmarkDiffing
    let backup: BookmarkBackup

    /// Shared store for the persisted security-scoped bookmark. Exposed so the
    /// app-layer authorization flow persists to the same location the readers
    /// resolve from.
    let bookmarkStore: BookmarkStore

    /// Shared bookmark creator, exposed for the app-layer authorization flow.
    let bookmarkCreator: SecurityScopedBookmarkCreating

    init(
        bookmarkReaders: [BookmarkReading],
        differ: BookmarkDiffing,
        backup: BookmarkBackup,
        bookmarkStore: BookmarkStore,
        bookmarkCreator: SecurityScopedBookmarkCreating
    ) {
        self.bookmarkReaders = bookmarkReaders
        self.differ = differ
        self.backup = backup
        self.bookmarkStore = bookmarkStore
        self.bookmarkCreator = bookmarkCreator
    }
}

extension AppDependencies {
    /// The production graph: the real Safari read-only reader, wired through the
    /// persisted security-scoped bookmark. Chrome is intentionally absent until
    /// it is implemented. Diff and backup use in-memory doubles for now.
    static func bootstrap() -> AppDependencies {
        let store = ApplicationSupportBookmarkStore.inApplicationSupport()
        let creator = SystemSecurityScopedBookmarkCreator()

        let safariReader = SafariBookmarkReader(
            locator: AuthorizedSafariSourceLocator(
                store: store,
                resolver: SystemSecurityScopedBookmarkResolver(),
                creator: creator
            ),
            fileAccess: SandboxFileAccessProvider(),
            decoder: SafariBookmarkDecoder()
        )

        return AppDependencies(
            bookmarkReaders: [safariReader],
            differ: InMemoryBookmarkDiffer(),
            backup: InMemoryBackupStore(),
            bookmarkStore: store,
            bookmarkCreator: creator
        )
    }
}
