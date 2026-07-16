//
//  SyncModelTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("Sync plan & changes")
struct SyncModelTests {

    @Test("An empty plan reports isEmpty and a zero count")
    func emptyPlan() {
        let plan = SyncPlan(source: .safari, target: .chrome, changes: [])
        #expect(plan.isEmpty)
        #expect(plan.count == 0)
    }

    @Test("A non-empty plan reports its change count")
    func nonEmptyPlan() {
        let plan = SyncPlan(
            source: .safari,
            target: .chrome,
            changes: [
                .remove(id: BookmarkID("x")),
                .rename(id: BookmarkID("y"), newTitle: "New"),
            ]
        )
        #expect(!plan.isEmpty)
        #expect(plan.count == 2)
    }

    @Test("Each change kind produces a human-readable summary")
    func changeSummaries() {
        let node = BookmarkNode.bookmark(
            Bookmark(id: BookmarkID("b"), title: "Docs", url: URL(string: "https://d.example")!)
        )
        #expect(SyncChange.add(node: node, parent: nil, sourcePath: []).summary.contains("Docs"))
        #expect(SyncChange.remove(id: BookmarkID("b")).summary.contains("b"))
        #expect(SyncChange.rename(id: BookmarkID("b"), newTitle: "X").summary.contains("X"))
    }
}
