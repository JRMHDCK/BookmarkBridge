//
//  DashboardViewModel.swift
//  BookmarkBridge
//

import Foundation
import Observation

/// Presentation state and orchestration for the dashboard.
///
/// State is tracked **per source**. Sources are discovered dynamically through
/// `BrowserSourceProviding`: a single-profile browser (Safari) yields one source;
/// a multi-profile browser (Chrome) yields one per profile once authorized.
/// Before a browser is authorized, a single **browser-level** card stands in for
/// its (not-yet-known) sources.
///
/// The ViewModel depends only on the provider/reader/authorizer abstractions —
/// never on file formats, the sandbox, or AppKit. Reading is strictly read-only.
@MainActor
@Observable
final class DashboardViewModel {
    /// The status of a single source on the dashboard.
    enum Status: Equatable {
        case loading
        case loaded(BrowserBookmarkSummary)
        case authorizationRequired
        case failed(String)
    }

    /// A source and its current status (ordered for stable display).
    struct SourceState: Identifiable, Equatable {
        let source: BookmarkSource
        var status: Status
        var id: BookmarkSourceID { source.id }
    }

    private(set) var sources: [SourceState] = []

    /// True while any source is loading — used to disable the global refresh.
    var isLoading: Bool {
        sources.contains { $0.status == .loading }
    }

    private let providers: [any BrowserSourceProviding]
    private let authorizer: (any BookmarkAuthorizationRequesting)?
    private var readers: [BookmarkSourceID: any BookmarkReading] = [:]

    /// The decoded tree kept for each loaded source, so the explorer can browse
    /// it without re-reading. Refreshed on every (re)load.
    private var trees: [BookmarkSourceID: BookmarkTree] = [:]

    init(
        providers: [any BrowserSourceProviding],
        authorizer: (any BookmarkAuthorizationRequesting)? = nil
    ) {
        self.providers = providers
        self.authorizer = authorizer
    }

    /// Initial load (invoked on appear).
    func load() async {
        await reloadAll()
    }

    /// Rediscovers and reloads every browser. Never prompts for authorization on
    /// its own — an unauthorized browser simply shows an `authorizationRequired`
    /// card.
    func reloadAll() async {
        sources = []
        readers = [:]
        trees = [:]
        for provider in providers {
            await discover(provider)
        }
    }

    /// The decoded tree for a loaded source, if available (for the explorer).
    func tree(for sourceID: BookmarkSourceID) -> BookmarkTree? {
        trees[sourceID]
    }

    /// The loaded sources paired with their decoded trees, for global search.
    /// A read-only view of in-memory state — no file access; sources still
    /// loading or in error are omitted.
    var searchableSources: [SearchableSource] {
        sources.compactMap { state in
            guard let tree = trees[state.id] else { return nil }
            return SearchableSource(source: state.source, tree: tree)
        }
    }

    /// Reloads a single card ("Réessayer"). A discovered source re-reads itself;
    /// a browser-level card re-runs discovery. Never prompts.
    func retry(_ sourceID: BookmarkSourceID) async {
        if let reader = readers[sourceID] {
            setStatus(.loading, for: sourceID)
            await refresh(reader)
        } else if let provider = provider(for: sourceID.browser) {
            await discover(provider)
        }
    }

    /// Requests authorization for a source's browser, then rediscovers it on
    /// success. Cancellation returns silently to the authorization prompt; a
    /// genuine failure is surfaced as `.failed`.
    func authorize(_ sourceID: BookmarkSourceID) async {
        guard let authorizer, let provider = provider(for: sourceID.browser) else { return }
        setStatus(.loading, for: sourceID)
        do {
            let granted = try await authorizer.requestAuthorization(for: sourceID.browser)
            if granted {
                await discover(provider)
            } else {
                setBrowserLevelStatus(.authorizationRequired, for: sourceID.browser)
            }
        } catch {
            setBrowserLevelStatus(.failed(message(for: error)), for: sourceID.browser)
        }
    }

    // MARK: - Discovery & reading

    private func discover(_ provider: any BrowserSourceProviding) async {
        do {
            let discovered = try await provider.makeReaders()
            replaceSources(for: provider.browser, with: discovered)
            for reader in discovered {
                await refresh(reader)
            }
        } catch let error as BookmarkError where Self.isAuthorizationRequired(error) {
            setBrowserLevelStatus(.authorizationRequired, for: provider.browser)
        } catch {
            setBrowserLevelStatus(.failed(message(for: error)), for: provider.browser)
        }
    }

    private func refresh(_ reader: any BookmarkReading) async {
        do {
            let tree = try await reader.readBookmarkTree()
            trees[reader.source.id] = tree
            setStatus(.loaded(BrowserBookmarkSummary(tree: tree)), for: reader.source.id)
        } catch let error as BookmarkError where Self.isAuthorizationRequired(error) {
            trees[reader.source.id] = nil
            setStatus(.authorizationRequired, for: reader.source.id)
        } catch {
            trees[reader.source.id] = nil
            setStatus(.failed(message(for: error)), for: reader.source.id)
        }
    }

    // MARK: - Sources bookkeeping

    private func provider(for browser: Browser) -> (any BrowserSourceProviding)? {
        providers.first { $0.browser == browser }
    }

    /// Replaces a browser's cards (in place) with the discovered per-source cards.
    private func replaceSources(for browser: Browser, with discovered: [any BookmarkReading]) {
        removeStoredData(for: browser)
        let index = insertionIndex(for: browser)
        sources.removeAll { $0.source.browser == browser }
        let newStates = discovered.map { reader -> SourceState in
            readers[reader.source.id] = reader
            return SourceState(source: reader.source, status: .loading)
        }
        sources.insert(contentsOf: newStates, at: min(index, sources.count))
    }

    /// Replaces a browser's cards (in place) with a single browser-level card.
    private func setBrowserLevelStatus(_ status: Status, for browser: Browser) {
        removeStoredData(for: browser)
        let index = insertionIndex(for: browser)
        sources.removeAll { $0.source.browser == browser }
        let source = BookmarkSource(browser: browser, displayName: browser.displayName)
        sources.insert(SourceState(source: source, status: status), at: min(index, sources.count))
    }

    private func setStatus(_ status: Status, for sourceID: BookmarkSourceID) {
        guard let index = sources.firstIndex(where: { $0.id == sourceID }) else { return }
        sources[index].status = status
    }

    private func insertionIndex(for browser: Browser) -> Int {
        sources.firstIndex { $0.source.browser == browser } ?? sources.count
    }

    private func removeStoredData(for browser: Browser) {
        for key in readers.keys where key.browser == browser {
            readers[key] = nil
        }
        for key in trees.keys where key.browser == browser {
            trees[key] = nil
        }
    }

    private static func isAuthorizationRequired(_ error: BookmarkError) -> Bool {
        if case .authorizationRequired = error { return true }
        return false
    }

    /// Maps an error to a simple, non-technical French message for the UI.
    private func message(for error: Error) -> String {
        guard let bookmarkError = error as? BookmarkError else {
            return "Une erreur est survenue."
        }
        switch bookmarkError {
        case .sourceNotFound:
            return "Fichier des favoris introuvable."
        case .accessDenied:
            return "Accès refusé au fichier."
        case .decodingFailed:
            return "Format du fichier illisible."
        case .unsupportedBrowser:
            return "Navigateur non pris en charge."
        case .unknownNode, .authorizationRequired:
            return "Une erreur est survenue."
        }
    }
}
