//
//  BSECoreModelTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("BSE core models")
struct BSECoreModelTests {

    private func logicalID(_ value: Int) throws -> LogicalNodeID {
        let string = String(format: "00000000-0000-0000-0000-%012d", value)
        return LogicalNodeID(try #require(UUID(uuidString: string)))
    }

    private func sourceID(_ value: Int) throws -> BSESourceID {
        let string = String(format: "10000000-0000-0000-0000-%012d", value)
        return BSESourceID(try #require(UUID(uuidString: string)))
    }

    private func folder(
        _ id: LogicalNodeID,
        title: String = "Folder",
        parentID: LogicalNodeID? = nil,
        position: Int = 0
    ) throws -> BSENode {
        try BSENode(
            logicalID: id,
            kind: .folder,
            title: title,
            parentID: parentID,
            position: position
        )
    }

    private func bookmark(
        _ id: LogicalNodeID,
        title: String = "Bookmark",
        parentID: LogicalNodeID? = nil,
        position: Int = 0,
        url: String = "https://example.com/"
    ) throws -> BSENode {
        try BSENode(
            logicalID: id,
            kind: .bookmark,
            title: title,
            parentID: parentID,
            position: position,
            url: URL(string: url)
        )
    }

    // MARK: - Nodes and identifiers

    @Test("Creates a folder without bookmark payload")
    func createsFolder() throws {
        let node = try folder(logicalID(1), title: "Reading")

        #expect(node.kind == .folder)
        #expect(node.title == "Reading")
        #expect(node.parentID == nil)
        #expect(node.position == 0)
        #expect(node.url == nil)
        #expect(try BSERoot(node: node).node == node)
    }

    @Test("Creates a bookmark with its URL payload")
    func createsBookmark() throws {
        let parentID = try logicalID(1)
        let node = try bookmark(
            logicalID(2),
            title: "Swift",
            parentID: parentID,
            position: 3,
            url: "https://swift.org/"
        )

        #expect(node.kind == .bookmark)
        #expect(node.parentID == parentID)
        #expect(node.position == 3)
        #expect(node.url == URL(string: "https://swift.org/"))
    }

    @Test("LogicalNodeID equality and hashing are stable")
    func logicalIdentifierIsStable() throws {
        let first = try logicalID(42)
        let same = LogicalNodeID(first.rawValue)
        let other = try logicalID(43)

        #expect(first == same)
        #expect(first != other)
        #expect(Set([first, same, other]).count == 2)
        #expect(first.description == first.rawValue.uuidString)
    }

    @Test("BSE values survive a Codable round-trip")
    func codableRoundTrip() throws {
        let rootID = try logicalID(1)
        let tree = try BSETree(nodes: [
            folder(rootID),
            bookmark(logicalID(2), parentID: rootID),
        ])
        let snapshot = BSESnapshot(
            source: try sourceID(1),
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            tree: tree
        )

        let encoded = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(BSESnapshot.self, from: encoded)

        #expect(decoded == snapshot)
    }

    @Test("Rejects a bookmark without a URL")
    func rejectsBookmarkWithoutURL() throws {
        let id = try logicalID(1)
        #expect(throws: BSEModelValidationError.bookmarkRequiresURL(id)) {
            _ = try BSENode(
                logicalID: id,
                kind: .bookmark,
                title: "Invalid",
                position: 0
            )
        }
    }

    @Test("Rejects a folder carrying a URL")
    func rejectsFolderWithURL() throws {
        let id = try logicalID(1)
        let url = try #require(URL(string: "https://example.com/"))
        #expect(throws: BSEModelValidationError.folderMustNotHaveURL(id)) {
            _ = try BSENode(
                logicalID: id,
                kind: .folder,
                title: "Invalid",
                position: 0,
                url: url
            )
        }
    }

    // MARK: - Tree validation and ordering

    @Test("Accepts a folder as a logical library root")
    func acceptsFolderRoot() throws {
        let rootID = try logicalID(1)
        let tree = try BSETree(nodes: [folder(rootID, title: "Library")])

        #expect(tree.roots.count == 1)
        #expect(tree.roots.first?.id == rootID)
        #expect(tree.roots.first?.node.kind == .folder)
    }

    @Test("Rejects a bookmark as a logical library root")
    func rejectsBookmarkRoot() throws {
        let rootID = try logicalID(1)
        let root = try bookmark(rootID)

        #expect(throws: BSEModelValidationError.bookmarkCannotBeRoot(rootID)) {
            _ = try BSETree(nodes: [root])
        }
        #expect(throws: BSEModelValidationError.bookmarkCannotBeRoot(rootID)) {
            _ = try BSERoot(node: root)
        }
    }

    @Test("Builds a valid tree with deterministic lookup")
    func buildsValidTree() throws {
        let rootID = try logicalID(1)
        let childID = try logicalID(2)
        let tree = try BSETree(nodes: [
            bookmark(childID, parentID: rootID),
            folder(rootID),
        ])

        #expect(tree.count == 2)
        #expect(tree.roots.map(\.id) == [rootID])
        #expect(tree.node(for: childID)?.parentID == rootID)
        #expect(tree.children(of: rootID).map(\.logicalID) == [childID])
    }

    @Test("Rejects a node whose parent does not exist")
    func rejectsMissingParent() throws {
        let nodeID = try logicalID(1)
        let parentID = try logicalID(99)
        let node = try folder(nodeID, parentID: parentID)

        #expect(throws: BSEModelValidationError.parentNotFound(nodeID: nodeID, parentID: parentID)) {
            _ = try BSETree(nodes: [node])
        }
    }

    @Test("Rejects a direct self-parent cycle")
    func rejectsDirectCycle() throws {
        let id = try logicalID(1)
        let node = try folder(id, parentID: id)

        #expect(throws: BSEModelValidationError.cycleDetected(id)) {
            _ = try BSETree(nodes: [node])
        }
    }

    @Test("Rejects an indirect parent cycle")
    func rejectsIndirectCycle() throws {
        let firstID = try logicalID(1)
        let secondID = try logicalID(2)
        let thirdID = try logicalID(3)
        let first = try folder(firstID, parentID: thirdID)
        let second = try folder(secondID, parentID: firstID)
        let third = try folder(thirdID, parentID: secondID)

        #expect(throws: BSEModelValidationError.cycleDetected(firstID)) {
            _ = try BSETree(nodes: [third, second, first])
        }
    }

    @Test("Rejects duplicate LogicalNodeIDs")
    func rejectsDuplicateIdentifier() throws {
        let id = try logicalID(1)
        let first = try folder(id, title: "First")
        let duplicate = try folder(id, title: "Duplicate")

        #expect(throws: BSEModelValidationError.duplicateLogicalNodeID(id)) {
            _ = try BSETree(nodes: [first, duplicate])
        }
    }

    @Test("Tree order is deterministic regardless of construction order")
    func treeOrderIsDeterministic() throws {
        let rootID = try logicalID(1)
        let firstChildID = try logicalID(2)
        let tiedChildID = try logicalID(3)
        let lastChildID = try logicalID(4)
        let nodes = [
            try folder(rootID, position: 0),
            try bookmark(lastChildID, parentID: rootID, position: 2),
            try bookmark(tiedChildID, parentID: rootID, position: 0),
            try bookmark(firstChildID, parentID: rootID, position: 0),
        ]

        let forward = try BSETree(nodes: nodes)
        let reversed = try BSETree(nodes: Array(nodes.reversed()))
        let expected = [rootID, firstChildID, tiedChildID, lastChildID]

        #expect(forward.nodes.map(\.logicalID) == expected)
        #expect(reversed.nodes.map(\.logicalID) == expected)
        #expect(forward == reversed)
    }

    @Test("Snapshot owns an immutable value copy of its complete tree")
    func snapshotIsImmutableByConstruction() throws {
        let rootID = try logicalID(1)
        var input = [try folder(rootID)]
        let snapshot = BSESnapshot(
            source: try sourceID(1),
            capturedAt: .distantPast,
            tree: try BSETree(nodes: input)
        )

        input.append(try bookmark(logicalID(2), parentID: rootID))

        #expect(input.count == 2)
        #expect(snapshot.tree.count == 1)
        #expect(snapshot.tree.nodes.map(\.logicalID) == [rootID])
    }

    // MARK: - Events

    @Test("Creates all four event kinds with explanatory before and after data")
    func createsAllEventKinds() throws {
        let id = try logicalID(1)
        let firstParentID = try logicalID(10)
        let secondParentID = try logicalID(11)
        let original = try folder(id, title: "Original", parentID: firstParentID)
        let renamed = try folder(id, title: "Renamed", parentID: firstParentID)
        let moved = try folder(id, title: "Original", parentID: secondParentID)

        let created = try BSEEvent(kind: .createNode, logicalID: id, before: nil, after: original)
        let deleted = try BSEEvent(kind: .deleteNode, logicalID: id, before: original, after: nil)
        let rename = try BSEEvent(kind: .renameNode, logicalID: id, before: original, after: renamed)
        let move = try BSEEvent(kind: .moveNode, logicalID: id, before: original, after: moved)

        #expect(created.kind == .createNode)
        #expect(created.before == nil)
        #expect(created.after == original)
        #expect(deleted.kind == .deleteNode)
        #expect(deleted.before == original)
        #expect(deleted.after == nil)
        #expect(rename.kind == .renameNode)
        #expect(rename.before?.title == "Original")
        #expect(rename.after?.title == "Renamed")
        #expect(move.kind == .moveNode)
        #expect(move.before?.parentID == firstParentID)
        #expect(move.after?.parentID == secondParentID)

        let encoded = try JSONEncoder().encode([created, deleted, rename, move])
        let decoded = try JSONDecoder().decode([BSEEvent].self, from: encoded)
        #expect(decoded == [created, deleted, rename, move])
    }

    @Test("Rejects an event whose states do not match its declared kind")
    func rejectsIncoherentEvent() throws {
        let id = try logicalID(1)
        let firstParentID = try logicalID(10)
        let secondParentID = try logicalID(11)
        let before = try folder(id, title: "Original", parentID: firstParentID)
        let after = try folder(id, title: "Renamed", parentID: secondParentID)

        #expect(throws: BSEModelValidationError.invalidEventState(.renameNode)) {
            _ = try BSEEvent(
                kind: .renameNode,
                logicalID: id,
                before: before,
                after: after
            )
        }
    }
}
