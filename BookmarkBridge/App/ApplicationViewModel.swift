//
//  ApplicationViewModel.swift
//  BookmarkBridge
//

import Foundation
import Observation

/// Coordinates feature ViewModels without exposing browser formats or BSE
/// internals to the application shell.
@MainActor
@Observable
final class ApplicationViewModel {
    struct BrowserClosurePrompt: Identifiable, Hashable {
        let id = UUID()
        let browsers: [Browser]
    }

    enum BrowserProtectedAction: Hashable {
        case initialLoad
        case reload
        case authorize(Browser)
        case retry(BookmarkSourceID)
        case synchronize
    }

    var selection: ApplicationScreen = .dashboard

    let dashboard: DashboardViewModel
    let authorization: ApplicationAuthorizationViewModel
    let synchronization: SynchronizationViewModel
    private(set) var browserClosurePrompt: BrowserClosurePrompt?
    private(set) var browserClosureError: String?

    private var hasLoaded = false
    private let browserOperationGuard: BrowserOperationGuard
    private var pendingBrowserProtectedAction: BrowserProtectedAction?

    init(
        dashboard: DashboardViewModel,
        authorization: ApplicationAuthorizationViewModel,
        synchronization: SynchronizationViewModel,
        browserOperationGuard: BrowserOperationGuard
    ) {
        self.dashboard = dashboard
        self.authorization = authorization
        self.synchronization = synchronization
        self.browserOperationGuard = browserOperationGuard
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
        guard requestBrowserClosureIfNeeded(for: .initialLoad) else { return }
        hasLoaded = true
        await performInitialLoad()
    }

    private func performInitialLoad() async {
        await authorization.restore()
        await dashboard.load()
        await loadSynchronizationPreview()
    }

    func reload() async {
        guard requestBrowserClosureIfNeeded(for: .reload) else { return }
        await performReload()
    }

    private func performReload() async {
        await authorization.restore()
        await dashboard.reloadAll()
        await loadSynchronizationPreview()
    }

    func authorize(_ browser: Browser) async {
        guard requestBrowserClosureIfNeeded(for: .authorize(browser)) else {
            return
        }
        await authorization.authorize(browser)
        await dashboard.reloadAll()
        await loadSynchronizationPreview()
    }

    func retry(_ sourceID: BookmarkSourceID) async {
        guard requestBrowserClosureIfNeeded(for: .retry(sourceID)) else {
            return
        }
        await dashboard.retry(sourceID)
        await loadSynchronizationPreview()
    }

    @discardableResult
    func synchronize() async -> Bool {
        guard canSynchronize else { return false }
        guard requestBrowserClosureIfNeeded(for: .synchronize) else {
            return false
        }
        let succeeded = await synchronization.synchronize()
        guard succeeded else { return false }
        await dashboard.reloadAll()
        await loadSynchronizationPreview()
        return true
    }

    func cancelBrowserClosure() {
        pendingBrowserProtectedAction = nil
        browserClosurePrompt = nil
    }

    func closeBrowsersAndContinue() async {
        guard let prompt = browserClosurePrompt,
              let action = pendingBrowserProtectedAction else {
            return
        }
        browserClosurePrompt = nil
        pendingBrowserProtectedAction = nil
        do {
            try await browserOperationGuard.closeAndWait(
                for: prompt.browsers
            )
            await resume(action)
        } catch is CancellationError {
            browserClosureError = "La fermeture des navigateurs a été annulée. Aucune donnée n’a été lue ou écrite."
        } catch {
            browserClosureError = [
                "Impossible de fermer complètement les navigateurs.",
                "Aucune donnée n’a été lue ou écrite.",
                "\(String(reflecting: type(of: error))): \(String(describing: error))",
            ].joined(separator: " ")
        }
    }

    func dismissBrowserClosureError() {
        browserClosureError = nil
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

    private func requestBrowserClosureIfNeeded(
        for action: BrowserProtectedAction
    ) -> Bool {
        let running = browserOperationGuard.runningBrowsers()
        guard running.isEmpty else {
            pendingBrowserProtectedAction = action
            browserClosurePrompt = BrowserClosurePrompt(browsers: running)
            return false
        }
        return true
    }

    private func resume(_ action: BrowserProtectedAction) async {
        switch action {
        case .initialLoad:
            guard !hasLoaded else { return }
            guard requestBrowserClosureIfNeeded(for: action) else { return }
            hasLoaded = true
            await performInitialLoad()
        case .reload:
            await reload()
        case .authorize(let browser):
            await authorize(browser)
        case .retry(let sourceID):
            await retry(sourceID)
        case .synchronize:
            _ = await synchronize()
        }
    }
}
