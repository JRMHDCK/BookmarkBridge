//
//  SearchViewModel.swift
//  BookmarkBridge
//

import Foundation
import Observation

/// Presentation state and orchestration for global search.
///
/// It owns only the *state* — the query, the in-memory sources to search, and
/// the results — and delegates **all** matching, ranking and relevance to a
/// `BookmarkSearching` engine. The ViewModel contains no search algorithm: it
/// forwards the query and sources to the engine and republishes its output.
///
/// Searching is read-only and works exclusively on trees already held in memory
/// (handed in via ``updateSources(_:)``); it never reads a file.
@MainActor
@Observable
final class SearchViewModel {

    /// The results of one source, kept together for grouped display. Preserves
    /// the engine's ranking within the group; performs no ranking of its own.
    struct SourceGroup: Identifiable {
        let source: BookmarkSource
        let results: [BookmarkSearchResult]
        var id: BookmarkSourceID { source.id }
    }

    /// The current query text. Editing it re-runs the search immediately.
    var query: String = "" {
        didSet { refresh() }
    }

    /// The ranked results for the current query, exactly as the engine returned
    /// them (no reordering or filtering here).
    private(set) var results: [BookmarkSearchResult] = []

    private let engine: any BookmarkSearching
    private var sources: [SearchableSource] = []

    init(engine: any BookmarkSearching) {
        self.engine = engine
    }

    /// Updates the in-memory sources to search (e.g. when the dashboard finishes
    /// loading or reloading trees) and re-runs the current query against them.
    func updateSources(_ sources: [SearchableSource]) {
        self.sources = sources
        refresh()
    }

    /// Whether the query holds anything other than whitespace.
    var hasQuery: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// True when the user has typed a query but nothing matched.
    var showsNoResults: Bool {
        hasQuery && results.isEmpty
    }

    /// The results grouped by source, in the order each source first appears in
    /// the ranked list. Pure presentation structuring — no ranking or filtering.
    var resultsBySource: [SourceGroup] {
        var order: [BookmarkSourceID] = []
        var grouped: [BookmarkSourceID: [BookmarkSearchResult]] = [:]
        for result in results {
            let id = result.source.id
            if grouped[id] == nil { order.append(id) }
            grouped[id, default: []].append(result)
        }
        return order.compactMap { id in
            guard let group = grouped[id], let source = group.first?.source else { return nil }
            return SourceGroup(source: source, results: group)
        }
    }

    /// Recomputes results by delegating to the engine. The only place the engine
    /// is called; it holds every matching/ranking rule.
    private func refresh() {
        results = engine.search(query, in: sources)
    }
}
