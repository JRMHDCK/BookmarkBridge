//
//  BreadcrumbTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("Breadcrumb")
struct BreadcrumbTests {

    private let safari = BookmarkSource.singleProfile(.safari)
    private let tree = BookmarkTree(browser: .safari, roots: [], capturedAt: .distantPast)

    private func folder(_ id: String, _ title: String) -> BookmarkFolder {
        BookmarkFolder(id: BookmarkID(id), title: title)
    }

    @Test("An empty path yields no crumbs")
    func emptyPath() {
        #expect(Breadcrumb(path: []).items.isEmpty)
    }

    @Test("A source-only path yields a single current crumb")
    func sourceOnly() {
        let path: [ExplorerStep] = [.source(safari, tree)]
        let breadcrumb = Breadcrumb(path: path)

        #expect(breadcrumb.items.count == 1)
        let item = breadcrumb.items[0]
        #expect(item.id == 0)
        #expect(item.title == "Safari")
        #expect(item.isCurrent)
        #expect(item.path == path)
    }

    @Test("Source + folder yields two crumbs; only the last is current")
    func sourceAndFolder() {
        let dev = folder("dev", "Dev")
        let path: [ExplorerStep] = [.source(safari, tree), .folder(dev)]
        let items = Breadcrumb(path: path).items

        #expect(items.count == 2)

        #expect(items[0].title == "Safari")
        #expect(items[0].isCurrent == false)
        #expect(items[0].path == [.source(safari, tree)])

        #expect(items[1].title == "Dev")
        #expect(items[1].isCurrent)
        #expect(items[1].path == path)
    }

    @Test("Folder crumbs use the friendly Safari root name")
    func friendlyRootName() {
        let path: [ExplorerStep] = [.source(safari, tree), .folder(folder("bar", "BookmarksBar"))]
        #expect(Breadcrumb(path: path).items[1].title == "Barre des favoris")
    }

    @Test("A deep path truncates each crumb to its prefix")
    func deepPathPrefixes() {
        let a = folder("a", "A")
        let b = folder("b", "B")
        let c = folder("c", "C")
        let path: [ExplorerStep] = [.source(safari, tree), .folder(a), .folder(b), .folder(c)]
        let items = Breadcrumb(path: path).items

        #expect(items.map(\.title) == ["Safari", "A", "B", "C"])
        #expect(items.map(\.id) == [0, 1, 2, 3])
        #expect(items[0].path == Array(path.prefix(1)))
        #expect(items[1].path == Array(path.prefix(2)))
        #expect(items[2].path == Array(path.prefix(3)))
        #expect(items[3].path == path)
        #expect(items.filter(\.isCurrent).map(\.id) == [3])   // only the last
    }

    // MARK: - Layout (overflow folding)

    private func path(depth: Int) -> [ExplorerStep] {
        var steps: [ExplorerStep] = [.source(safari, tree)]
        for index in 1..<max(depth, 1) {
            steps.append(.folder(folder("f\(index)", "F\(index)")))
        }
        return steps
    }

    @Test("A short trail is not collapsed")
    func layoutNotCollapsed() {
        let breadcrumb = Breadcrumb(path: path(depth: 4))   // 4 items ≤ maxVisible
        let layout = breadcrumb.layout(maxVisible: 4, trailingCount: 2)

        #expect(layout.isCollapsed == false)
        #expect(layout.leading.isEmpty)
        #expect(layout.collapsed.isEmpty)
        #expect(layout.trailing == breadcrumb.items)
    }

    @Test("A long trail keeps the source and the last levels, folding the middle")
    func layoutCollapsed() {
        let breadcrumb = Breadcrumb(path: path(depth: 6))   // 6 items > maxVisible
        let layout = breadcrumb.layout(maxVisible: 4, trailingCount: 2)

        #expect(layout.isCollapsed)
        #expect(layout.leading.map(\.id) == [0])                 // source
        #expect(layout.collapsed.map(\.id) == [1, 2, 3])         // folded middle
        #expect(layout.trailing.map(\.id) == [4, 5])             // last levels
    }

    @Test("Collapsing appears exactly one past the visible limit")
    func layoutBoundary() {
        #expect(Breadcrumb(path: path(depth: 4)).layout(maxVisible: 4, trailingCount: 2).isCollapsed == false)
        #expect(Breadcrumb(path: path(depth: 5)).layout(maxVisible: 4, trailingCount: 2).isCollapsed)
    }
}
