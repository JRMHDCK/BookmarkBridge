//
//  ApplicationViewModel.swift
//  BookmarkBridge
//

import Observation

/// Coordinates feature ViewModels without exposing browser formats or BSE
/// internals to the application shell.
@MainActor
@Observable
final class ApplicationViewModel {
    var selection: ApplicationScreen = .dashboard

    let dashboard: DashboardViewModel
    let authorization: ApplicationAuthorizationViewModel
    let synchronization: SynchronizationViewModel

    private var hasLoaded = false

    init(
        dashboard: DashboardViewModel,
        authorization: ApplicationAuthorizationViewModel,
        synchronization: SynchronizationViewModel
    ) {
        self.dashboard = dashboard
        self.authorization = authorization
        self.synchronization = synchronization
    }

    var dashboardSynchronizationSummary: DashboardSynchronizationSummary {
        switch synchronization.state {
        case .idle:
            .idle
        case .loading:
            .loading
        case .loaded(let preview):
            .changes(preview.totalOperationCount)
        case .empty:
            .upToDate
        case .failed(let message):
            .failed(message)
        }
    }

    var canSynchronize: Bool {
        authorization.state.status == .complete
            && synchronization.canSynchronize
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await authorization.restore()
        await dashboard.load()
        await loadSynchronizationPreview()
    }

    func reload() async {
        await authorization.restore()
        await dashboard.reloadAll()
        await loadSynchronizationPreview()
    }

    func authorize(_ browser: Browser) async {
        await authorization.authorize(browser)
        await dashboard.reloadAll()
        await loadSynchronizationPreview()
    }

    func retry(_ sourceID: BookmarkSourceID) async {
        await dashboard.retry(sourceID)
        await loadSynchronizationPreview()
    }

    @discardableResult
    func synchronize() async -> Bool {
        guard canSynchronize else { return false }
        let succeeded = await synchronization.synchronize()
        guard succeeded else { return false }
        await dashboard.reloadAll()
        await loadSynchronizationPreview()
        return true
    }

    func showSynchronization() {
        selection = .synchronization
    }

    func loadSynchronizationPreview() async {
        guard let (safari, chrome) = synchronizationSourcePair else {
            synchronization.reset()
            return
        }
        await synchronization.loadPreview(
            safari: safari,
            chrome: chrome
        )
    }

    private var synchronizationSourcePair: (
        SynchronizationSourceSummary,
        SynchronizationSourceSummary
    )? {
        let sources = dashboard.searchableSources
        guard let safari = sources.first(where: {
            $0.source.browser == .safari
        }),
        let chrome = sources.first(where: {
            $0.source.browser == .chrome
        }) else {
            return nil
        }
        return (
            SynchronizationSourceSummary(
                source: safari.source,
                summary: BrowserBookmarkSummary(tree: safari.tree)
            ),
            SynchronizationSourceSummary(
                source: chrome.source,
                summary: BrowserBookmarkSummary(tree: chrome.tree)
            )
        )
    }
}
