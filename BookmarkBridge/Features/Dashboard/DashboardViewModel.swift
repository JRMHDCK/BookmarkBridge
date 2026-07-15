//
//  DashboardViewModel.swift
//  BookmarkBridge
//

import Foundation
import Observation

/// Presentation state and orchestration for the dashboard.
///
/// State is tracked **per source** (a browser, optionally narrowed to a profile),
/// so a browser with several profiles (Chrome) shows one card per profile, and
/// adding a browser stays additive. The ViewModel depends only on
/// `BookmarkReading` (to read) and, optionally, on `BookmarkAuthorizationRequesting`
/// (to (re)authorize) — never on file formats, the sandbox, or AppKit. Reading is
/// strictly read-only.
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

    private let readers: [BookmarkReading]
    private let authorizer: (any BookmarkAuthorizationRequesting)?

    init(
        readers: [BookmarkReading],
        authorizer: (any BookmarkAuthorizationRequesting)? = nil
    ) {
        self.readers = readers
        self.authorizer = authorizer
    }

    /// Initial load (invoked on appear).
    func load() async {
        await reloadAll()
    }

    /// Reloads every configured source. It never prompts for authorization on
    /// its own — an unauthorized source simply stays `.authorizationRequired`.
    func reloadAll() async {
        sources = readers.map { SourceState(source: $0.source, status: .loading) }
        for reader in readers {
            await refresh(reader)
        }
    }

    /// Reloads a single source (used by "Réessayer"). It never prompts; if
    /// authorization is missing, the status naturally returns to
    /// `.authorizationRequired`.
    func retry(_ sourceID: BookmarkSourceID) async {
        guard let reader = reader(for: sourceID) else { return }
        setStatus(.loading, for: sourceID)
        await refresh(reader)
    }

    /// Requests authorization for a source, then reloads it on success. A user
    /// cancellation returns silently to the authorization prompt; a genuine
    /// failure is surfaced as `.failed`.
    func authorize(_ sourceID: BookmarkSourceID) async {
        guard let authorizer, let reader = reader(for: sourceID) else { return }
        setStatus(.loading, for: sourceID)
        do {
            let granted = try await authorizer.requestAuthorization(for: sourceID.browser)
            if granted {
                await refresh(reader)
            } else {
                setStatus(.authorizationRequired, for: sourceID)
            }
        } catch {
            setStatus(.failed(message(for: error)), for: sourceID)
        }
    }

    // MARK: - Private

    private func refresh(_ reader: BookmarkReading) async {
        do {
            let tree = try await reader.readBookmarkTree()
            setStatus(.loaded(BrowserBookmarkSummary(tree: tree)), for: reader.source.id)
        } catch let error as BookmarkError {
            if case .authorizationRequired = error {
                setStatus(.authorizationRequired, for: reader.source.id)
            } else {
                setStatus(.failed(message(for: error)), for: reader.source.id)
            }
        } catch {
            setStatus(.failed(message(for: error)), for: reader.source.id)
        }
    }

    private func reader(for sourceID: BookmarkSourceID) -> BookmarkReading? {
        readers.first { $0.source.id == sourceID }
    }

    private func setStatus(_ status: Status, for sourceID: BookmarkSourceID) {
        guard let index = sources.firstIndex(where: { $0.id == sourceID }) else { return }
        sources[index].status = status
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
