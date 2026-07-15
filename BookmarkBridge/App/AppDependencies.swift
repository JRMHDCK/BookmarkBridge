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
/// During the read-only bootstrapping phase there are **no real browser readers
/// yet** (no file access exists). The default graph is therefore wired with
/// in-memory doubles, which keeps the app runnable and the UI buildable without
/// ever touching real bookmarks (see CLAUDE.md and ADR-0002).
nonisolated struct AppDependencies {
    let bookmarkReaders: [BookmarkReading]
    let differ: BookmarkDiffing
    let backup: BookmarkBackup

    init(
        bookmarkReaders: [BookmarkReading],
        differ: BookmarkDiffing,
        backup: BookmarkBackup
    ) {
        self.bookmarkReaders = bookmarkReaders
        self.differ = differ
        self.backup = backup
    }
}

extension AppDependencies {
    /// The default graph for the current phase: in-memory doubles only.
    ///
    /// Real Safari/Chrome readers and file access are intentionally absent until
    /// the architecture, models, protocols, ViewModels, and base unit tests are
    /// complete.
    static func bootstrap() -> AppDependencies {
        AppDependencies(
            bookmarkReaders: [
                InMemoryBookmarkReader(browser: .safari, tree: .sample(for: .safari)),
                InMemoryBookmarkReader(browser: .chrome, tree: .sample(for: .chrome)),
            ],
            differ: InMemoryBookmarkDiffer(),
            backup: InMemoryBackupStore()
        )
    }
}
