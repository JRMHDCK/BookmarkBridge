//
//  AppDependencies.swift
//  BookmarkBridge
//

import Foundation

/// The composition root's dependency graph.
///
/// Holds the concrete services the app runs against, all behind `Core`
/// abstractions so that features depend on protocols, never implementations. It
/// is assembled once and injected downward.
///
/// Safari and Chrome are wired to their **real** read-only chains via
/// `BrowserSourceProviding`. Before the user authorizes access, sources surface
/// `authorizationRequired`; the authorization actions are wired at the app layer
/// (macOS). Diff and backup remain in-memory doubles — those features are not
/// implemented yet.
nonisolated struct AppDependencies {
    let providers: [any BrowserSourceProviding]
    let differ: BookmarkDiffing
    let backup: BookmarkBackup

    /// Shared store for the persisted security-scoped bookmarks. Exposed so the
    /// app-layer authorization flow persists to the same location the providers
    /// resolve from.
    let bookmarkStore: BookmarkStore

    /// Shared bookmark creator, exposed for the app-layer authorization flow.
    let bookmarkCreator: SecurityScopedBookmarkCreating

    init(
        providers: [any BrowserSourceProviding],
        differ: BookmarkDiffing,
        backup: BookmarkBackup,
        bookmarkStore: BookmarkStore,
        bookmarkCreator: SecurityScopedBookmarkCreating
    ) {
        self.providers = providers
        self.differ = differ
        self.backup = backup
        self.bookmarkStore = bookmarkStore
        self.bookmarkCreator = bookmarkCreator
    }
}

extension AppDependencies {
    /// The production graph: real Safari and Chrome read-only providers, wired
    /// through the persisted security-scoped bookmarks. Diff and backup use
    /// in-memory doubles for now.
    static func bootstrap() -> AppDependencies {
        let store = ApplicationSupportBookmarkStore.inApplicationSupport()
        let creator = SystemSecurityScopedBookmarkCreator()
        let resolver = SystemSecurityScopedBookmarkResolver()

        let backupsRoot = (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("BookmarkBridge/Backups", isDirectory: true)

        let safariReader = SafariBookmarkReader(
            locator: AuthorizedBookmarkSourceLocator(
                browser: .safari,
                store: store,
                resolver: resolver,
                creator: creator
            ),
            fileAccess: SandboxFileAccessProvider(),
            decoder: SafariBookmarkDecoder()
        )
        let safariProvider = SafariSourceProvider(reader: safariReader)

        let chromeProvider = ChromeSourceProvider(
            directoryLocator: AuthorizedBookmarkSourceLocator(
                browser: .chrome,
                store: store,
                resolver: resolver,
                creator: creator
            ),
            fileAccess: SandboxFileAccessProvider(),
            profileLocator: DefaultChromeProfileLocator(),
            decoder: ChromeBookmarkDecoder()
        )

        return AppDependencies(
            providers: [safariProvider, chromeProvider],
            differ: AdditiveBookmarkDiffer(),
            backup: FileBookmarkBackup(rootDirectory: backupsRoot),
            bookmarkStore: store,
            bookmarkCreator: creator
        )
    }
}
