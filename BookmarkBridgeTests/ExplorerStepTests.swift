//
//  ExplorerStepTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("ExplorerStep")
struct ExplorerStepTests {

    private let safari = BookmarkSource.singleProfile(.safari)
    private let chrome = BookmarkSource(browser: .chrome, profile: "Default", displayName: "Chrome — Perso")
    private let tree = BookmarkTree(browser: .safari, roots: [], capturedAt: .distantPast)

    private func folder(_ id: String) -> BookmarkFolder {
        BookmarkFolder(id: BookmarkID(id), title: id)
    }

    @Test("Equal source steps are equal; different sources differ")
    func sourceEquality() {
        #expect(ExplorerStep.source(safari, tree) == .source(safari, tree))
        #expect(ExplorerStep.source(safari, tree) != .source(chrome, tree))
    }

    @Test("Equal folder steps are equal; different folders differ")
    func folderEquality() {
        #expect(ExplorerStep.folder(folder("a")) == .folder(folder("a")))
        #expect(ExplorerStep.folder(folder("a")) != .folder(folder("b")))
    }

    @Test("A source step never equals a folder step")
    func sourceNeverEqualsFolder() {
        #expect(ExplorerStep.source(safari, tree) != .folder(folder("a")))
    }

    @Test("Distinct steps hash into a set as distinct elements")
    func hashableInSet() {
        let steps: Set<ExplorerStep> = [
            .source(safari, tree),
            .source(chrome, tree),
            .folder(folder("a")),
            .folder(folder("a")),   // duplicate
        ]
        #expect(steps.count == 3)
    }

    // MARK: - path(to:in:) — search result navigation

    /// Safari tree: Barre › (Apple, Dev › Café).
    private func searchTree() -> BookmarkTree {
        let cafe = Bookmark(id: BookmarkID("s.cafe"), title: "Café", url: URL(string: "https://cafe.example.com")!)
        let dev = BookmarkFolder(id: BookmarkID("s.dev"), title: "Dev", children: [.bookmark(cafe)])
        let apple = Bookmark(id: BookmarkID("s.apple"), title: "Apple", url: URL(string: "https://apple.com")!)
        let bar = BookmarkFolder(id: BookmarkID("s.bar"), title: "Barre", children: [.bookmark(apple), .folder(dev)])
        return BookmarkTree(browser: .safari, roots: [bar], capturedAt: .distantPast)
    }

    private func component(_ id: String, _ title: String) -> BookmarkPathComponent {
        BookmarkPathComponent(id: BookmarkID(id), title: title)
    }

    private func folderIDs(_ steps: [ExplorerStep]) -> [BookmarkID] {
        steps.compactMap { if case .folder(let folder) = $0 { folder.id } else { nil } }
    }

    @Test("A nested bookmark hit resolves to source + its ancestor folders")
    func pathToNestedBookmark() {
        let tree = searchTree()
        let result = BookmarkSearchResult(
            source: safari,
            node: .bookmark(Bookmark(id: BookmarkID("s.cafe"), title: "Café", url: URL(string: "https://cafe.example.com")!)),
            path: [component("s.bar", "Barre"), component("s.dev", "Dev")],
            relevance: .exactTitle
        )

        let steps = ExplorerStep.path(to: result, in: tree)

        // Source first, then Barre, then Dev (the bookmark's parent) — no folder
        // step for the bookmark itself.
        #expect(steps.count == 3)
        if case .source(let source, _) = steps.first {
            #expect(source.id == safari.id)
        } else {
            Issue.record("expected the first step to be the source")
        }
        #expect(folderIDs(steps) == [BookmarkID("s.bar"), BookmarkID("s.dev")])
    }

    @Test("A folder hit ends on the folder itself")
    func pathToFolder() {
        let tree = searchTree()
        let dev = BookmarkFolder(id: BookmarkID("s.dev"), title: "Dev")
        let result = BookmarkSearchResult(
            source: safari,
            node: .folder(dev),
            path: [component("s.bar", "Barre")],
            relevance: .exactTitle
        )

        let steps = ExplorerStep.path(to: result, in: tree)

        // Barre (ancestor) then Dev (the hit folder, opened).
        #expect(folderIDs(steps) == [BookmarkID("s.bar"), BookmarkID("s.dev")])
    }

    @Test("A root-level bookmark hit resolves to source + its root folder")
    func pathToRootBookmark() {
        let tree = searchTree()
        let result = BookmarkSearchResult(
            source: safari,
            node: .bookmark(Bookmark(id: BookmarkID("s.apple"), title: "Apple", url: URL(string: "https://apple.com")!)),
            path: [component("s.bar", "Barre")],
            relevance: .exactTitle
        )

        let steps = ExplorerStep.path(to: result, in: tree)

        #expect(steps.count == 2)
        #expect(folderIDs(steps) == [BookmarkID("s.bar")])
    }

    @Test("An unknown ancestor id stops resolution gracefully")
    func pathStopsOnUnknownComponent() {
        let tree = searchTree()
        let result = BookmarkSearchResult(
            source: safari,
            node: .bookmark(Bookmark(id: BookmarkID("x"), title: "X", url: URL(string: "https://x.example.com")!)),
            path: [component("missing", "Nope"), component("s.dev", "Dev")],
            relevance: .other
        )

        let steps = ExplorerStep.path(to: result, in: tree)

        // Only the source survives; resolution stops at the unknown component.
        #expect(steps.count == 1)
        #expect(folderIDs(steps).isEmpty)
    }
}
