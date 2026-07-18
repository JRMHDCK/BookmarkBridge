//
//  BSEDiffEngineTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("BSE Diff Engine")
struct BSEDiffEngineTests {
    private let engine = DiffEngine()

    private func logicalID(_ value: Int) throws -> LogicalNodeID {
        let string = String(format: "30000000-0000-0000-0000-%012d", value)
        return LogicalNodeID(try #require(UUID(uuidString: string)))
    }

    private func folder(
        _ value: Int,
        title: String = "Folder",
        parent: Int? = nil,
        position: Int = 0
    ) throws -> BSENode {
        try BSENode(
            logicalID: logicalID(value),
            kind: .folder,
            title: title,
            parentID: try parent.map(logicalID),
            position: position
        )
    }

    private func bookmark(
        _ value: Int,
        title: String = "Bookmark",
        parent: Int = 1,
        position: Int = 0,
        url: String = "https://example.com/"
    ) throws -> BSENode {
        try BSENode(
            logicalID: logicalID(value),
            kind: .bookmark,
            title: title,
            parentID: logicalID(parent),
            position: position,
            url: URL(string: url)
        )
    }

    private func snapshot(_ nodes: [BSENode], capturedAt: TimeInterval = 0) throws -> BSESnapshot {
        BSESnapshot(
            source: BSESourceID(try #require(UUID(uuidString: "40000000-0000-0000-0000-000000000001"))),
            capturedAt: Date(timeIntervalSince1970: capturedAt),
            tree: try BSETree(nodes: nodes)
        )
    }

    @Test("Identical snapshots have no differences")
    func identicalSnapshots() throws {
        let nodes = [try folder(1, title: "Root"), try bookmark(2)]
        let before = try snapshot(nodes)
        let after = try snapshot(nodes, capturedAt: 10)

        let result = try engine.diff(from: before, to: after)

        #expect(result.isEmpty)
        #expect(result.events == [])
    }

    @Test("Creates a folder")
    func createsFolder() throws {
        let before = try snapshot([folder(1, title: "Root")])
        let created = try folder(2, title: "Created", parent: 1)
        let after = try snapshot([folder(1, title: "Root"), created])

        let entry = try #require(engine.diff(from: before, to: after).entries.first)

        #expect(entry.event.kind == .createNode)
        #expect(entry.event.after == created)
        #expect(entry.reason == .createdInAfterSnapshot)
    }

    @Test("Creates a bookmark")
    func createsBookmark() throws {
        let before = try snapshot([folder(1, title: "Root")])
        let created = try bookmark(2, title: "Created")
        let after = try snapshot([folder(1, title: "Root"), created])

        let entry = try #require(engine.diff(from: before, to: after).entries.first)

        #expect(entry.event.kind == .createNode)
        #expect(entry.event.after == created)
        #expect(entry.reason == .createdInAfterSnapshot)
    }

    @Test("Deletes a folder")
    func deletesFolder() throws {
        let deleted = try folder(2, title: "Deleted", parent: 1)
        let before = try snapshot([folder(1, title: "Root"), deleted])
        let after = try snapshot([folder(1, title: "Root")])

        let entry = try #require(engine.diff(from: before, to: after).entries.first)

        #expect(entry.event.kind == .deleteNode)
        #expect(entry.event.before == deleted)
        #expect(entry.reason == .missingFromAfterSnapshot)
    }

    @Test("Deletes a bookmark")
    func deletesBookmark() throws {
        let deleted = try bookmark(2, title: "Deleted")
        let before = try snapshot([folder(1, title: "Root"), deleted])
        let after = try snapshot([folder(1, title: "Root")])

        let entry = try #require(engine.diff(from: before, to: after).entries.first)

        #expect(entry.event.kind == .deleteNode)
        #expect(entry.event.before == deleted)
        #expect(entry.reason == .missingFromAfterSnapshot)
    }

    @Test(arguments: [NodeKind.folder, .bookmark])
    func renamesNode(kind: NodeKind) throws {
        let beforeNode = try kind == .folder
            ? folder(2, title: "Before", parent: 1)
            : bookmark(2, title: "Before")
        let afterNode = try kind == .folder
            ? folder(2, title: "After", parent: 1)
            : bookmark(2, title: "After")
        let before = try snapshot([folder(1, title: "Root"), beforeNode])
        let after = try snapshot([folder(1, title: "Root"), afterNode])

        let entry = try #require(engine.diff(from: before, to: after).entries.first)

        #expect(entry.event.kind == .renameNode)
        #expect(entry.event.before == beforeNode)
        #expect(entry.event.after == afterNode)
        #expect(entry.reason == .titleChanged)
    }

    @Test("Moving to another parent produces one move")
    func movesToAnotherParent() throws {
        let oldNode = try bookmark(4, parent: 2)
        let newNode = try bookmark(4, parent: 3)
        let fixed = [try folder(1, title: "Root"), try folder(2, parent: 1), try folder(3, parent: 1)]

        let result = try engine.diff(
            from: snapshot(fixed + [oldNode]),
            to: snapshot(fixed + [newNode])
        )

        #expect(result.events.map(\.kind) == [.moveNode])
        #expect(result.entries.first?.reason == .parentChanged)
    }

    @Test("Changing position under the same parent produces one move")
    func movesWithinParent() throws {
        let oldNode = try bookmark(2, position: 0)
        let newNode = try bookmark(2, position: 3)
        let root = try folder(1, title: "Root")

        let result = try engine.diff(
            from: snapshot([root, oldNode]),
            to: snapshot([root, newNode])
        )

        #expect(result.events.map(\.kind) == [.moveNode])
        #expect(result.entries.first?.reason == .positionChanged)
    }

    @Test("Moving and renaming produces two atomic events")
    func movesAndRenames() throws {
        let oldNode = try bookmark(4, title: "Before", parent: 2, position: 0)
        let newNode = try bookmark(4, title: "After", parent: 3, position: 1)
        let fixed = [try folder(1, title: "Root"), try folder(2, parent: 1), try folder(3, parent: 1)]

        let result = try engine.diff(
            from: snapshot(fixed + [oldNode]),
            to: snapshot(fixed + [newNode])
        )

        #expect(result.events.map(\.kind) == [.moveNode, .renameNode])
        #expect(result.entries.map(\.reason) == [.parentAndPositionChanged, .titleChanged])
        #expect(result.events[0].after == result.events[1].before)
        #expect(result.events[0].after?.title == "Before")
        #expect(result.events[1].after == newNode)
    }

    @Test("Changing a bookmark URL produces create then delete only")
    func changesBookmarkURL() throws {
        let oldNode = try bookmark(2, title: "Before", position: 0, url: "https://old.example/")
        let newNode = try bookmark(2, title: "After", position: 2, url: "https://new.example/")
        let root = try folder(1, title: "Root")

        let result = try engine.diff(
            from: snapshot([root, oldNode]),
            to: snapshot([root, newNode])
        )

        #expect(result.events.map(\.kind) == [.createNode, .deleteNode])
        #expect(result.entries.map(\.reason) == [.bookmarkURLChanged, .bookmarkURLChanged])
        #expect(result.events[0].after == newNode)
        #expect(result.events[1].before == oldNode)
    }

    @Test("Changing node kind is an explicit integrity error")
    func rejectsNodeKindChange() throws {
        let id = try logicalID(2)
        let oldNode = try folder(2, parent: 1)
        let newNode = try BSENode(
            logicalID: id,
            kind: .bookmark,
            title: "Bookmark",
            parentID: logicalID(1),
            position: 0,
            url: URL(string: "https://example.com/")
        )
        let root = try folder(1, title: "Root")

        #expect(throws: DiffEngineError.nodeKindChanged(
            logicalID: id,
            before: .folder,
            after: .bookmark
        )) {
            try engine.diff(
                from: snapshot([root, oldNode]),
                to: snapshot([root, newNode])
            )
        }
    }

    @Test("Renaming a folder does not affect unchanged descendants")
    func renamesFolderWithoutDescendantEvents() throws {
        let root = try folder(1, title: "Root")
        let descendant = try bookmark(3, parent: 2)
        let before = try snapshot([root, folder(2, title: "Before", parent: 1), descendant])
        let after = try snapshot([root, folder(2, title: "After", parent: 1), descendant])

        let result = try engine.diff(from: before, to: after)

        #expect(result.events.map(\.kind) == [.renameNode])
        #expect(result.events.map(\.logicalID) == [try logicalID(2)])
    }

    @Test("Moving a folder does not affect unchanged descendants")
    func movesFolderWithoutDescendantEvents() throws {
        let fixed = [try folder(1, title: "Root"), try folder(2, parent: 1), try folder(3, parent: 1)]
        let descendant = try bookmark(5, parent: 4)
        let before = try snapshot(fixed + [folder(4, parent: 2), descendant])
        let after = try snapshot(fixed + [folder(4, parent: 3), descendant])

        let result = try engine.diff(from: before, to: after)

        #expect(result.events.map(\.kind) == [.moveNode])
        #expect(result.events.map(\.logicalID) == [try logicalID(4)])
    }

    @Test("Folders precede bookmarks inside one event category")
    func ordersFoldersBeforeBookmarks() throws {
        let root = try folder(1, title: "Root")
        let createdBookmark = try bookmark(2)
        let createdFolder = try folder(3, parent: 1)

        let result = try engine.diff(
            from: snapshot([root]),
            to: snapshot([root, createdBookmark, createdFolder])
        )

        #expect(result.events.map { $0.after?.kind } == [.folder, .bookmark])
    }

    @Test("Event categories are ordered create, delete, move, rename")
    func ordersEventCategories() throws {
        let root = try folder(1, title: "Root")
        let deleted = try bookmark(2)
        let movedBefore = try bookmark(3, position: 0)
        let movedAfter = try bookmark(3, position: 1)
        let renamedBefore = try bookmark(4, title: "Before")
        let renamedAfter = try bookmark(4, title: "After")
        let created = try bookmark(5)

        let result = try engine.diff(
            from: snapshot([root, deleted, movedBefore, renamedBefore]),
            to: snapshot([root, movedAfter, renamedAfter, created])
        )

        #expect(result.events.map(\.kind) == [.createNode, .deleteNode, .moveNode, .renameNode])
    }

    @Test("Logical identifiers are the stable tie-breaker")
    func sortsByLogicalIdentifier() throws {
        let root = try folder(1, title: "Root")
        let lower = try bookmark(2)
        let higher = try bookmark(3)

        let result = try engine.diff(
            from: snapshot([root]),
            to: snapshot([higher, root, lower])
        )

        #expect(result.events.map(\.logicalID) == [try logicalID(2), try logicalID(3)])
    }

    @Test("Input enumeration order does not influence the diff")
    func ignoresInputEnumerationOrder() throws {
        let beforeNodes = [
            try folder(1, title: "Root"),
            try folder(2, title: "Before", parent: 1),
            try bookmark(3, parent: 2),
        ]
        let afterNodes = [
            try folder(1, title: "Root"),
            try folder(2, title: "After", parent: 1),
            try bookmark(3, parent: 2),
            try bookmark(4),
        ]

        let forward = try engine.diff(
            from: snapshot(beforeNodes),
            to: snapshot(afterNodes)
        )
        let reversed = try engine.diff(
            from: snapshot(Array(beforeNodes.reversed())),
            to: snapshot(Array(afterNodes.reversed()))
        )

        #expect(forward == reversed)
    }

    @Test("Repeated executions are deterministic and leave snapshots unchanged")
    func isDeterministicAndImmutable() throws {
        let before = try snapshot([
            folder(1, title: "Root"),
            bookmark(2, title: "Before", position: 0),
        ])
        let after = try snapshot([
            folder(1, title: "Root"),
            bookmark(2, title: "After", position: 1),
            bookmark(3),
        ])
        let beforeCopy = before
        let afterCopy = after

        let first = try engine.diff(from: before, to: after)
        for _ in 0..<10 {
            #expect(try engine.diff(from: before, to: after) == first)
        }

        #expect(before == beforeCopy)
        #expect(after == afterCopy)
    }
}
