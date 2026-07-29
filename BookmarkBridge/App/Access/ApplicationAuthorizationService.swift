//
//  ApplicationAuthorizationService.swift
//  BookmarkBridge
//

import Foundation

/// Restores, validates, refreshes, and interactively acquires the two
/// application-level security-scoped bookmarks.
///
/// The service owns no browser data and performs no synchronization. It stores
/// only opaque bookmark data through `BookmarkStore`; resolved paths remain
/// transient.
@MainActor
final class ApplicationAuthorizationService:
    ApplicationAuthorizationManaging,
    BookmarkAuthorizationRequesting,
    Sendable
{
    private let store: any BookmarkStore
    private let resolver: any SecurityScopedBookmarkResolving
    private let creator: any SecurityScopedBookmarkCreating
    private let fileController: any SecurityScopedFileControlling
    private let requester: any BookmarkAuthorizationRequesting

    init(
        store: any BookmarkStore,
        resolver: any SecurityScopedBookmarkResolving,
        creator: any SecurityScopedBookmarkCreating,
        fileController: any SecurityScopedFileControlling,
        requester: any BookmarkAuthorizationRequesting
    ) {
        self.store = store
        self.resolver = resolver
        self.creator = creator
        self.fileController = fileController
        self.requester = requester
    }

    func restoreAuthorizations() async -> ApplicationAuthorizationState {
        ApplicationAuthorizationState(
            safari: validate(.safari),
            chrome: validate(.chrome)
        )
    }

    func requestAuthorizationState(
        for browser: Browser
    ) async -> ApplicationAuthorizationState {
        do {
            let granted = try await requester.requestAuthorization(for: browser)
            guard granted else {
                return await restoreAuthorizations()
            }
            return await restoreAuthorizations()
        } catch {
            let restored = await restoreAuthorizations()
            return replacing(
                browser,
                with: .accessError(.authorizationFailed),
                in: restored
            )
        }
    }

    /// Compatibility with the existing dashboard source cards. Both the
    /// dedicated authorization card and the legacy per-source action therefore
    /// use the same service and persisted store.
    func requestAuthorization(for browser: Browser) async throws -> Bool {
        try await requester.requestAuthorization(for: browser)
    }

    private func validate(_ browser: Browser) -> BrowserAuthorizationState {
        let bookmark: Data
        do {
            guard let stored = try store.loadBookmark(for: browser) else {
                return .missing
            }
            bookmark = stored
        } catch {
            return .accessError(.storageUnavailable)
        }

        let resolution: ResolvedBookmark
        do {
            resolution = try resolver.resolve(bookmark)
        } catch {
            return .invalidBookmark
        }

        guard isExpectedLocation(resolution.url, for: browser) else {
            return .invalidBookmark
        }

        let didStartAccess = fileController.startAccessing(resolution.url)
        defer {
            if didStartAccess {
                fileController.stopAccessing(resolution.url)
            }
        }

        guard fileController.fileExists(at: resolution.url),
              fileController.isReadable(at: resolution.url) else {
            return .accessError(.locationUnavailable)
        }

        if resolution.isStale {
            do {
                let refreshed = try creator.makeBookmark(for: resolution.url)
                try store.saveBookmark(refreshed, for: browser)
            } catch {
                return .accessError(.bookmarkRefreshFailed)
            }
        }

        return .valid
    }

    private func isExpectedLocation(_ url: URL, for browser: Browser) -> Bool {
        var path = url.path(percentEncoded: false)
        if path.hasSuffix("/") {
            path.removeLast()
        }
        switch browser {
        case .safari:
            return path.hasSuffix(BrowserAccessCoordinator.safariPathSuffix)
        case .chrome:
            return path.hasSuffix(
                BrowserAccessCoordinator.chromeDirectorySuffix
            )
        }
    }

    private func replacing(
        _ browser: Browser,
        with browserState: BrowserAuthorizationState,
        in state: ApplicationAuthorizationState
    ) -> ApplicationAuthorizationState {
        switch browser {
        case .safari:
            ApplicationAuthorizationState(
                safari: browserState,
                chrome: state.chrome
            )
        case .chrome:
            ApplicationAuthorizationState(
                safari: state.safari,
                chrome: browserState
            )
        }
    }
}
