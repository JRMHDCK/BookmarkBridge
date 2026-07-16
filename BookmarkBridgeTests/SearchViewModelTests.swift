//
//  SearchViewModelTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@MainActor
@Suite("SearchViewModel")
struct SearchViewModelTests {

    // MARK: - Doubles

    /// A stand-in engine: records what it was asked and returns whatever it is
    /// told to, so the tests exercise the ViewModel's orchestration only — never
    /// any real matching or ranking.
    private final class SearchEngineSpy: BookmarkSearching, @unchecked Sendable {
        private(set) var receivedQueries: [String] = []
        private(set) var receivedSources: [[SearchableSource]] = []
        var resultProvider: (@Sendable (String, [SearchableSource]) -> [BookmarkSearchResult])?

        func search(_ query: String, in sources: [SearchableSource]) -> [BookmarkSearchResult] {
            receivedQueries.append(query)
            receivedSources.append(sources)
            return resultProvider?(query, sources) ?? []
        }
    }

    // MARK: - Fixtures

    private let safari = BookmarkSource.singleProfile(.safari)
    private let chrome = BookmarkSource(browser: .chrome, profile: "Default", displayName: "Chrome — Perso")

    private func source(_ browser: Browser) -> SearchableSource {
        SearchableSource(source: .singleProfile(browser), tree: .sample(for: browser))
    }

    private func result(_ source: BookmarkSource, _ id: String, _ title: String) -> BookmarkSearchResult {
        BookmarkSearchResult(
            source: source,
            node: .bookmark(Bookmark(id: BookmarkID(id), title: title, url: URL(string: "https://example.com")!)),
            path: [],
            relevance: .other
        )
    }

    // MARK: - Delegation

    @Test("Setting the query forwards it and the sources to the engine")
    func forwardsQueryAndSources() {
        let spy = SearchEngineSpy()
        let sources = [source(.safari), source(.chrome)]
        let viewModel = SearchViewModel(engine: spy)
        viewModel.updateSources(sources)

        viewModel.query = "swift"

        #expect(spy.receivedQueries.last == "swift")
        #expect(spy.receivedSources.last == sources)
    }

    @Test("Results are exactly what the engine returns, in the same order")
    func republishesEngineOutputVerbatim() {
        let spy = SearchEngineSpy()
        // A deliberately unsorted list: if the ViewModel re-ranked or filtered,
        // this order would change.
        let canned = [
            result(safari, "b", "B"),
            result(chrome, "a", "A"),
            result(safari, "c", "C"),
        ]
        spy.resultProvider = { _, _ in canned }
        let viewModel = SearchViewModel(engine: spy)

        viewModel.query = "x"

        #expect(viewModel.results == canned)
    }

    @Test("Updating the sources re-runs the current query against them")
    func updatingSourcesReRunsSearch() {
        let spy = SearchEngineSpy()
        let viewModel = SearchViewModel(engine: spy)
        viewModel.query = "swift"

        let newSources = [source(.chrome)]
        viewModel.updateSources(newSources)

        #expect(spy.receivedQueries.last == "swift")
        #expect(spy.receivedSources.last == newSources)
    }

    // MARK: - Derived state

    @Test("hasQuery ignores whitespace")
    func hasQueryIgnoresWhitespace() {
        let viewModel = SearchViewModel(engine: SearchEngineSpy())
        #expect(viewModel.hasQuery == false)
        viewModel.query = "   "
        #expect(viewModel.hasQuery == false)
        viewModel.query = "a"
        #expect(viewModel.hasQuery)
    }

    @Test("showsNoResults only when a real query yields nothing")
    func showsNoResults() {
        let spy = SearchEngineSpy()   // returns [] by default
        let viewModel = SearchViewModel(engine: spy)

        #expect(viewModel.showsNoResults == false)   // no query
        viewModel.query = "zzz"
        #expect(viewModel.showsNoResults)             // query, no results

        let hit = [result(safari, "a", "A")]
        spy.resultProvider = { _, _ in hit }
        viewModel.query = "a"
        #expect(viewModel.showsNoResults == false)    // query with results
    }

    // MARK: - Grouping

    @Test("resultsBySource groups by source, preserving first-appearance order")
    func groupsBySourcePreservingOrder() {
        let spy = SearchEngineSpy()
        let canned = [
            result(safari, "s1", "S1"),
            result(chrome, "c1", "C1"),
            result(safari, "s2", "S2"),
        ]
        spy.resultProvider = { _, _ in canned }
        let viewModel = SearchViewModel(engine: spy)
        viewModel.query = "x"

        let groups = viewModel.resultsBySource
        #expect(groups.map(\.source.id) == [safari.id, chrome.id])
        #expect(groups.first?.results.map(\.node.id) == [BookmarkID("s1"), BookmarkID("s2")])
        #expect(groups.last?.results.map(\.node.id) == [BookmarkID("c1")])
    }

    @Test("An empty query produces no groups")
    func emptyQueryNoGroups() {
        let viewModel = SearchViewModel(engine: SearchEngineSpy())
        #expect(viewModel.resultsBySource.isEmpty)
    }
}
