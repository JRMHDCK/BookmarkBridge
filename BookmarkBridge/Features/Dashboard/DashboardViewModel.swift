//
//  DashboardViewModel.swift
//  BookmarkBridge
//

import Foundation
import Observation

/// Presentation state and orchestration for the dashboard.
///
/// State is tracked **per browser**, so adding a browser (Chrome, Firefox, Edge…)
/// is additive: each entry loads, fails, or requires authorization independently.
/// The ViewModel depends only on `BookmarkReading` (to read) and, optionally, on
/// `BookmarkAuthorizationRequesting` (to (re)authorize) — never on file formats,
/// the sandbox, or AppKit. Reading is strictly read-only.
@MainActor
@Observable
final class DashboardViewModel {
    /// The status of a single browser on the dashboard.
    enum Status: Equatable {
        case loading
        case loaded(BrowserBookmarkSummary)
        case authorizationRequired
        case failed(String)
    }

    /// A browser and its current status (ordered for stable display).
    struct BrowserState: Identifiable, Equatable {
        let browser: Browser
        var status: Status
        var id: Browser { browser }
    }

    private(set) var browsers: [BrowserState] = []

    private let readers: [BookmarkReading]
    private let authorizer: (any BookmarkAuthorizationRequesting)?

    init(
        readers: [BookmarkReading],
        authorizer: (any BookmarkAuthorizationRequesting)? = nil
    ) {
        self.readers = readers
        self.authorizer = authorizer
    }

    /// Reads every configured browser, updating each entry independently.
    func load() async {
        browsers = readers.map { BrowserState(browser: $0.browser, status: .loading) }
        for reader in readers {
            await refresh(reader)
        }
    }

    /// Requests authorization for `browser`, then reloads it on success. A user
    /// cancellation returns silently to the authorization prompt; a genuine
    /// failure is surfaced as `.failed`.
    func authorize(_ browser: Browser) async {
        guard let authorizer, let reader = reader(for: browser) else { return }
        setStatus(.loading, for: browser)
        do {
            let granted = try await authorizer.requestAuthorization(for: browser)
            if granted {
                await refresh(reader)
            } else {
                setStatus(.authorizationRequired, for: browser)
            }
        } catch {
            setStatus(.failed(String(describing: error)), for: browser)
        }
    }

    // MARK: - Private

    private func refresh(_ reader: BookmarkReading) async {
        do {
            let tree = try await reader.readBookmarkTree()
            setStatus(.loaded(BrowserBookmarkSummary(tree: tree)), for: reader.browser)
        } catch let error as BookmarkError {
            if case .authorizationRequired = error {
                setStatus(.authorizationRequired, for: reader.browser)
            } else {
                setStatus(.failed(String(describing: error)), for: reader.browser)
            }
        } catch {
            setStatus(.failed(String(describing: error)), for: reader.browser)
        }
    }

    private func reader(for browser: Browser) -> BookmarkReading? {
        readers.first { $0.browser == browser }
    }

    private func setStatus(_ status: Status, for browser: Browser) {
        if let index = browsers.firstIndex(where: { $0.browser == browser }) {
            browsers[index].status = status
        } else {
            browsers.append(BrowserState(browser: browser, status: status))
        }
    }
}
