//
//  BookmarkSearchEngineTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("BookmarkSearchEngine")
struct BookmarkSearchEngineTests {

    private let engine = BookmarkSearchEngine()

    // MARK: - Fixtures

    private func bookmark(_ id: String, _ title: String, _ url: String) -> BookmarkNode {
        .bookmark(Bookmark(id: BookmarkID(id), title: title, url: URL(string: url)!))
    }

    /// Safari tree: a "Barre" root holding some bookmarks and a "Dev" sub-folder.
    private var safari: SearchableSource {
        let dev = BookmarkFolder(
            id: BookmarkID("s.dev"),
            title: "Dev",
            children: [
                bookmark("s.cafe", "Café Central", "https://cafe.example.com"),
                bookmark("s.repo", "Repo", "https://github.com/foo/bar"),
            ]
        )
        let bar = BookmarkFolder(
            id: BookmarkID("s.bar"),
            title: "Barre",
            children: [
                bookmark("s.apple", "Apple", "https://www.apple.com"),
                bookmark("s.swift", "Swift", "https://www.swift.org"),
                bookmark("s.swiftevo", "Swift Evolution", "https://github.com/apple/swift-evolution"),
                bookmark("s.learn", "Apprendre Swift", "https://example.com/learn"),
                .folder(dev),
            ]
        )
        let tree = BookmarkTree(browser: .safari, roots: [bar], capturedAt: Date(timeIntervalSince1970: 0))
        return SearchableSource(source: .singleProfile(.safari), tree: tree)
    }

    /// Chrome tree (one profile): a bookmark also titled "Swift".
    private var chrome: SearchableSource {
        let bar = BookmarkFolder(
            id: BookmarkID("c.bar"),
            title: "Barre Chrome",
            children: [bookmark("c.swift", "Swift", "https://swift.org")]
        )
        let tree = BookmarkTree(browser: .chrome, roots: [bar], capturedAt: Date(timeIntervalSince1970: 0))
        let source = BookmarkSource(browser: .chrome, profile: "Default", displayName: "Chrome — Perso")
        return SearchableSource(source: source, tree: tree)
    }

    private var allSources: [SearchableSource] { [safari, chrome] }

    // MARK: - Empty query

    @Test("An empty or whitespace query returns no results")
    func emptyQueryReturnsNothing() {
        #expect(engine.search("", in: allSources).isEmpty)
        #expect(engine.search("   ", in: allSources).isEmpty)
    }

    // MARK: - Case & diacritics

    @Test("Matching is case- and diacritic-insensitive")
    func caseAndDiacriticInsensitive() {
        #expect(engine.search("APPLE", in: allSources).contains { $0.node.id == BookmarkID("s.apple") })
        // "cafe" (no accent, lowercase) must find "Café Central".
        #expect(engine.search("cafe", in: allSources).contains { $0.node.id == BookmarkID("s.cafe") })
    }

    // MARK: - Matched fields

    @Test("Matches on host and full URL, not only the title")
    func matchesHostAndURL() {
        // "github" appears only in URLs (Repo and Swift Evolution), never a title.
        let results = engine.search("github", in: allSources)
        let ids = Set(results.map(\.node.id))
        #expect(ids.contains(BookmarkID("s.repo")))
        #expect(ids.contains(BookmarkID("s.swiftevo")))
        #expect(results.allSatisfy { $0.relevance == .other })
        #expect(results.allSatisfy { !$0.isFolder })
    }

    @Test("Folders match on their name")
    func foldersMatchByName() {
        let results = engine.search("dev", in: allSources)
        #expect(results.count == 1)
        let hit = try? #require(results.first)
        #expect(hit?.isFolder == true)
        #expect(hit?.node.id == BookmarkID("s.dev"))
        #expect(hit?.relevance == .exactTitle)
        // "Dev" lives under the "Barre" root.
        #expect(hit?.path.map(\.title) == ["Barre"])
        #expect(hit?.path.map(\.id) == [BookmarkID("s.bar")])
    }

    // MARK: - Ranking

    @Test("Exact title beats prefix beats other")
    func rankingExactPrefixOther() {
        let results = engine.search("swift", in: allSources)
        // Relevance is non-decreasing across the ranked list.
        let relevances = results.map(\.relevance)
        #expect(relevances == relevances.sorted())

        // Exact-title hits come first: Safari "Swift" and Chrome "Swift".
        let exact = results.filter { $0.relevance == .exactTitle }.map(\.node.id)
        #expect(Set(exact) == [BookmarkID("s.swift"), BookmarkID("c.swift")])
        // "Swift Evolution" is a title prefix.
        #expect(results.contains { $0.node.id == BookmarkID("s.swiftevo") && $0.relevance == .titlePrefix })
        // "Apprendre Swift" only contains the term → other.
        #expect(results.contains { $0.node.id == BookmarkID("s.learn") && $0.relevance == .other })

        // The very first result is an exact match.
        #expect(results.first?.relevance == .exactTitle)
    }

    @Test("Tied exact matches order by source name (Chrome before Safari)")
    func tiedExactOrderBySource() {
        let results = engine.search("swift", in: allSources)
        let exact = results.prefix { $0.relevance == .exactTitle }
        #expect(exact.map(\.source.displayName) == ["Chrome — Perso", "Safari"])
    }

    // MARK: - Multi-source

    @Test("Results span every loaded source")
    func multiSourceResults() {
        let results = engine.search("swift", in: allSources)
        let sources = Set(results.map(\.source.id))
        #expect(sources.contains(BookmarkSourceID(browser: .safari)))
        #expect(sources.contains(BookmarkSourceID(browser: .chrome, profile: "Default")))
    }

    // MARK: - Path

    @Test("A nested hit carries the full ancestor chain")
    func nestedHitPath() {
        let results = engine.search("café", in: allSources)
        let hit = try? #require(results.first { $0.node.id == BookmarkID("s.cafe") })
        // Café Central lives under Barre › Dev.
        #expect(hit?.path.map(\.title) == ["Barre", "Dev"])
        #expect(hit?.path.map(\.id) == [BookmarkID("s.bar"), BookmarkID("s.dev")])
        #expect(hit?.relevance == .titlePrefix)   // "café central" starts with "cafe"
    }

    @Test("A root-level hit has a single-folder path")
    func rootLevelHitPath() {
        let hit = try? #require(engine.search("apple", in: allSources).first { $0.node.id == BookmarkID("s.apple") })
        #expect(hit?.path.map(\.id) == [BookmarkID("s.bar")])
        #expect(hit?.host == "www.apple.com")
    }

    // MARK: - Identity

    @Test("Every result has a unique identity")
    func resultIdentitiesAreUnique() {
        let results = engine.search("swift", in: allSources)
        #expect(Set(results.map(\.id)).count == results.count)
    }
}
