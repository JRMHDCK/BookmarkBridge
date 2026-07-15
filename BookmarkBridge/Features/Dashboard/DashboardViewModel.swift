//
//  DashboardViewModel.swift
//  BookmarkBridge
//

import Foundation
import Observation

/// Presentation state and orchestration for the dashboard.
///
/// Depends only on the `BookmarkReading` protocol (Dependency Inversion): it has
/// no knowledge of Safari, Chrome, file formats, or the sandbox. Reading is a
/// safe, read-only operation — the dashboard never mutates any bookmarks.
@MainActor
@Observable
final class DashboardViewModel {
    /// The phases the dashboard can be in.
    enum State: Equatable {
        case idle
        case loading
        case loaded([BrowserBookmarkSummary])
        case failed(String)
    }

    private(set) var state: State = .idle

    private let readers: [BookmarkReading]

    init(readers: [BookmarkReading]) {
        self.readers = readers
    }

    /// Reads every configured source and publishes a summary per browser.
    func load() async {
        state = .loading
        do {
            var summaries: [BrowserBookmarkSummary] = []
            for reader in readers {
                let tree = try await reader.readBookmarkTree()
                summaries.append(BrowserBookmarkSummary(tree: tree))
            }
            state = .loaded(summaries)
        } catch {
            state = .failed(String(describing: error))
        }
    }
}
