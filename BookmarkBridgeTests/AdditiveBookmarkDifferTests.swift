//
//  AdditiveBookmarkDifferTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("AdditiveBookmarkDiffer")
struct AdditiveBookmarkDifferTests {

    private let differ = AdditiveBookmarkDiffer()

    /// A tree with one root folder holding the given (id, title, url) bookmarks.
    private func tree(_ browser: Browser, _ items: [(String, String, String)]) -> BookmarkTree {
        let nodes = items.map { item in
            BookmarkNode.bookmark(Bookmark(id: BookmarkID(item.0), title: item.1, url: URL(string: item.2)!))
        }
        let root = BookmarkFolder(id: BookmarkID("\(browser.rawValue).root"), title: "Root", children: nodes)
        return BookmarkTree(browser: browser, roots: [root], capturedAt: .distantPast)
    }

    private func addedTitles(_ plan: SyncPlan) -> [String] {
        plan.changes.compactMap { change in
            if case .add(let node, _, _) = change { node.title } else { nil }
        }
    }

    @Test("No changes when the target already has every source URL")
    func emptyWhenTargetHasAll() {
        let source = tree(.safari, [("a", "Apple", "https://apple.com")])
        let target = tree(.chrome, [("b", "Apple (Chrome)", "https://apple.com")])
        #expect(differ.plan(from: source, to: target).isEmpty)
    }

    @Test("Proposes adds for source bookmarks missing from the target")
    func addsMissing() {
        let source = tree(.safari, [
            ("a", "Apple", "https://apple.com"),
            ("s", "Swift", "https://swift.org"),
        ])
        let target = tree(.chrome, [("b", "Apple", "https://apple.com")])

        let plan = differ.plan(from: source, to: target)
        #expect(addedTitles(plan) == ["Swift"])
    }

    @Test("Never proposes removals — only additions")
    func onlyAdditions() {
        let source = tree(.safari, [("s", "Swift", "https://swift.org")])
        let target = tree(.chrome, [("x", "Other", "https://example.com")])

        let plan = differ.plan(from: source, to: target)
        #expect(plan.changes.allSatisfy { if case .add = $0 { true } else { false } })
    }

    @Test("De-duplicates additions among themselves")
    func dedupesWithinSource() {
        let source = tree(.safari, [
            ("s1", "Swift", "https://swift.org"),
            ("s2", "Swift again", "https://swift.org/"),   // same normalized URL
        ])
        let target = tree(.chrome, [])

        let plan = differ.plan(from: source, to: target)
        #expect(plan.count == 1)
    }

    @Test("Matches by normalized URL (case / trailing slash not re-added)")
    func matchesByNormalizedURL() {
        let source = tree(.safari, [("s", "Swift", "https://Swift.org")])
        let target = tree(.chrome, [("t", "Swift", "https://swift.org/")])
        #expect(differ.plan(from: source, to: target).isEmpty)
    }

    @Test("A link and the same link with tracking params are one favourite")
    func trackingParamsDoNotDuplicate() {
        let source = tree(.safari, [("s", "Article", "https://example.com/a?utm_source=nl")])
        let target = tree(.chrome, [("t", "Article", "https://example.com/a")])
        #expect(differ.plan(from: source, to: target).isEmpty)
    }

    @Test("Distinct queries are treated as different pages")
    func distinctQueriesAreAdded() {
        let source = tree(.safari, [("s", "Search 1", "https://example.com/s?q=1")])
        let target = tree(.chrome, [("t", "Search 2", "https://example.com/s?q=2")])
        #expect(differ.plan(from: source, to: target).count == 1)
    }

    @Test("An added change carries the source bookmark's node")
    func addCarriesSourceNode() {
        let source = tree(.safari, [("s", "Swift", "https://swift.org")])
        let target = tree(.chrome, [])

        let plan = differ.plan(from: source, to: target)
        guard case .add(let node, let parent, let sourcePath) = try? #require(plan.changes.first) else {
            Issue.record("expected an .add change")
            return
        }
        #expect(node.title == "Swift")
        #expect(node.id == BookmarkID("s"))
        #expect(parent == nil)   // v1: concrete destination resolved at write time
        // The bookmark sat directly under the single "Root" folder.
        #expect(sourcePath.map(\.title) == ["Root"])
        #expect(sourcePath.map(\.id) == [BookmarkID("safari.root")])
    }

    @Test("The origin folder path is captured for nested bookmarks")
    func capturesNestedSourcePath() {
        // Safari: Bar › Dev › Swift  (Swift missing from an empty Chrome).
        let dev = BookmarkFolder(
            id: BookmarkID("dev"),
            title: "Dev",
            children: [.bookmark(Bookmark(id: BookmarkID("sw"), title: "Swift", url: URL(string: "https://swift.org")!))]
        )
        let bar = BookmarkFolder(id: BookmarkID("bar"), title: "Bar", children: [.folder(dev)])
        let source = BookmarkTree(browser: .safari, roots: [bar], capturedAt: .distantPast)
        let target = BookmarkTree(browser: .chrome, roots: [], capturedAt: .distantPast)

        let plan = differ.plan(from: source, to: target)
        guard case .add(_, _, let sourcePath) = try? #require(plan.changes.first) else {
            Issue.record("expected an .add change")
            return
        }
        #expect(sourcePath.map(\.title) == ["Bar", "Dev"])
        #expect(sourcePath.map(\.id) == [BookmarkID("bar"), BookmarkID("dev")])
    }

    @Test("The plan records the source and target browsers")
    func planCarriesBrowsers() {
        let plan = differ.plan(from: tree(.safari, []), to: tree(.chrome, []))
        #expect(plan.source == .safari)
        #expect(plan.target == .chrome)
    }

    @Test("Union is achieved by planning both directions")
    func bothDirectionsGiveUnion() {
        let safari = tree(.safari, [("a", "Apple", "https://apple.com")])
        let chrome = tree(.chrome, [("s", "Swift", "https://swift.org")])

        #expect(addedTitles(differ.plan(from: safari, to: chrome)) == ["Apple"])   // add Apple to Chrome
        #expect(addedTitles(differ.plan(from: chrome, to: safari)) == ["Swift"])   // add Swift to Safari
    }
}
