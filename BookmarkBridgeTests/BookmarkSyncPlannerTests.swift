//
//  BookmarkSyncPlannerTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("BookmarkSyncPlanner (dry-run)")
struct BookmarkSyncPlannerTests {

    private let planner = BookmarkSyncPlanner()

    private func tree(_ browser: Browser, _ items: [(String, String, String)]) -> BookmarkTree {
        let nodes = items.map { item in
            BookmarkNode.bookmark(Bookmark(id: BookmarkID(item.0), title: item.1, url: URL(string: item.2)!))
        }
        let root = BookmarkFolder(id: BookmarkID("\(browser.rawValue).root"), title: "Root", children: nodes)
        return BookmarkTree(browser: browser, roots: [root], capturedAt: .distantPast)
    }

    private func addedTitles(_ plan: SyncPlan?) -> [String] {
        (plan?.changes ?? []).compactMap { if case .add(let node, _, _) = $0 { node.title } else { nil } }
    }

    @Test("A dry-run previews both directions of the additive union")
    func previewsBothDirections() {
        let safari = tree(.safari, [("a", "Apple", "https://apple.com")])
        let chrome = tree(.chrome, [("s", "Swift", "https://swift.org")])

        let preview = planner.preview(between: safari, and: chrome)

        #expect(preview.plans.count == 2)
        #expect(addedTitles(preview.plan(addingTo: .chrome)) == ["Apple"])   // Apple → Chrome
        #expect(addedTitles(preview.plan(addingTo: .safari)) == ["Swift"])   // Swift → Safari
    }

    @Test("Identical trees preview as empty")
    func emptyWhenIdentical() {
        let safari = tree(.safari, [("a", "Apple", "https://apple.com")])
        let chrome = tree(.chrome, [("b", "Apple", "https://apple.com")])

        let preview = planner.preview(between: safari, and: chrome)
        #expect(preview.isEmpty)
        #expect(preview.totalChanges == 0)
    }

    @Test("Total change count sums both directions")
    func totalChangesSumsBothSides() {
        let safari = tree(.safari, [("a", "Apple", "https://apple.com"), ("g", "GitHub", "https://github.com")])
        let chrome = tree(.chrome, [("s", "Swift", "https://swift.org")])

        let preview = planner.preview(between: safari, and: chrome)
        // Two to add to Chrome (Apple, GitHub), one to add to Safari (Swift).
        #expect(preview.totalChanges == 3)
    }
}
