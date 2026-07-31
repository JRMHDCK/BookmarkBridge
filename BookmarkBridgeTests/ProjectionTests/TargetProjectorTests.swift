//
//  TargetProjectorTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("BSE Target Projector")
struct TargetProjectorTests {
    @Test("Safari authority projects creation, rename, move, URL, folders, and deletion to Chrome")
    func safariToChrome() throws {
        let source = try snapshot(source: safari, nodes: [
            folder(1, "Root"),
            folder(2, "Source Folder", parent: 1),
            bookmark(3, "Source Bookmark", parent: 2, url: "https://source.test"),
            bookmark(4, "Created", parent: 1, position: 1),
        ])
        let target = try snapshot(source: chrome, nodes: [
            folder(1, "Root"),
            folder(2, "Target Folder", parent: 1),
            bookmark(3, "Target Bookmark", parent: 1, url: "https://target.test"),
            bookmark(6, "Deleted", parent: 1, position: 1),
        ])

        let projection = try project(source: source, target: target)
        let diff = try LogicalDiffEngine().diff(request: .init(
            before: projection.before,
            after: projection.after
        ))

        #expect(projectedNodes(projection.before) == target.tree.nodes)
        #expect(projectedNodes(projection.after) == source.tree.nodes)
        #expect(diff.changes.contains {
            if case .created(let change) = $0 {
                change.logicalNodeID == logicalID(4)
            } else { false }
        })
        #expect(diff.changes.contains {
            if case .deleted(let change) = $0 {
                change.logicalNodeID == logicalID(6)
            } else { false }
        })
        #expect(diff.changes.contains {
            if case .renamed(let change) = $0 {
                change.logicalNodeID == logicalID(2)
            } else { false }
        })
        #expect(diff.changes.contains {
            if case .moved(let change) = $0 {
                change.logicalNodeID == logicalID(3)
            } else { false }
        })
        #expect(diff.changes.contains {
            if case .urlChanged(let change) = $0 {
                change.logicalNodeID == logicalID(3)
            } else { false }
        })
    }

    @Test("Chrome authority projects its exact root and deep hierarchy to Safari")
    func chromeToSafari() throws {
        let source = try snapshot(source: chrome, nodes: [
            folder(10, "Chrome Root"),
            folder(11, "Level 1", parent: 10),
            folder(12, "Level 2", parent: 11),
            bookmark(13, "Deep", parent: 12),
        ])
        let target = try snapshot(source: safari, nodes: [
            folder(10, "Safari Root"),
        ])

        let projection = try project(source: source, target: target)

        #expect(projectedNodes(projection.before) == target.tree.nodes)
        #expect(projectedNodes(projection.after) == source.tree.nodes)
        #expect(projection.after.node(for: logicalID(13))?.parentID == logicalID(12))
    }

    @Test("A source absence is projected as a target deletion")
    func deletion() throws {
        let source = try snapshot(source: safari, nodes: [
            folder(1, "Root"),
        ])
        let target = try snapshot(source: chrome, nodes: [
            folder(1, "Root"),
            bookmark(2, "Target Only", parent: 1),
        ])

        let projection = try project(source: source, target: target)
        let diff = try LogicalDiffEngine().diff(request: .init(
            before: projection.before,
            after: projection.after
        ))

        #expect(diff.changes == [
            .deleted(DeletedChange(
                before: try #require(projection.before.node(for: logicalID(2)))
            )),
        ])
    }

    @Test("Projection canonicalizes sparse browser positions after filtering")
    func canonicalizesSparseChildPositions() throws {
        let source = try snapshot(source: safari, nodes: [
            folder(1, "Root"),
            folder(2, "Only Retained Child", parent: 1, position: 22),
        ])
        let target = try snapshot(source: chrome, nodes: [
            folder(1, "Root"),
        ])

        let projection = try project(source: source, target: target)
        let diff = try LogicalDiffEngine().diff(request: .init(
            before: projection.before,
            after: projection.after
        ))
        let plan = try SynchronizationPlanner().plan(request: .init(
            before: projection.before,
            logicalDiff: diff,
            policy: .allChanges(direction: .oneWay(
                source: safari,
                target: chrome
            ))
        ))

        #expect(projection.after.node(for: logicalID(2))?.position == 0)
        #expect(plan.report.plannedOperationCount == 1)
    }

    @Test("Additions-only preserves target nodes and adds only missing source identities")
    func additionsOnly() throws {
        let source = try snapshot(source: safari, nodes: [
            folder(1, "Source Root"),
            bookmark(2, "Source Existing", parent: 1),
            bookmark(3, "Source New", parent: 1, position: 1),
        ])
        let target = try snapshot(source: chrome, nodes: [
            folder(1, "Target Root"),
            bookmark(2, "Target Existing", parent: 1),
            bookmark(4, "Target Only", parent: 1, position: 1),
        ])
        let direction = SynchronizationDirection.oneWay(
            source: safari,
            target: chrome
        )

        let projection = try TargetProjector().project(request: .init(
            sourceSnapshot: source,
            targetSnapshot: target,
            policy: .additionsOnly(direction: direction)
        ))
        let diff = try LogicalDiffEngine().diff(request: .init(
            before: projection.before,
            after: projection.after
        ))

        #expect(projection.after.node(for: logicalID(1))?.title == "Target Root")
        #expect(projection.after.node(for: logicalID(2))?.title == "Target Existing")
        #expect(projection.after.node(for: logicalID(4)) != nil)
        #expect(diff.changes.count == 1)
        #expect(diff.changes.first?.logicalNodeID == logicalID(3))
        #expect(projection.after.node(for: logicalID(3))?.position == 2)
        if case .created = diff.changes.first {
            // Expected.
        } else {
            Issue.record("The only projected change must be a creation")
        }
    }

    @Test("Additions-only translates sparse source positions into executable target positions")
    func additionsOnlyNormalizesSparseSourcePositions() throws {
        let source = try snapshot(source: safari, nodes: [
            folder(1, "Root"),
            folder(2, "Destination", parent: 1),
            bookmark(3, "Existing Elsewhere", parent: 1, position: 1),
            bookmark(4, "New", parent: 2, position: 22),
        ])
        let target = try snapshot(source: chrome, nodes: [
            folder(1, "Root"),
            folder(2, "Destination", parent: 1),
            bookmark(3, "Existing Elsewhere", parent: 1, position: 1),
        ])
        let direction = SynchronizationDirection.oneWay(
            source: safari,
            target: chrome
        )
        let policy = SynchronizationPolicy.additionsOnly(direction: direction)

        let projection = try TargetProjector().project(request: .init(
            sourceSnapshot: source,
            targetSnapshot: target,
            policy: policy
        ))
        let diff = try LogicalDiffEngine().diff(request: .init(
            before: projection.before,
            after: projection.after
        ))
        let plan = try SynchronizationPlanner().plan(request: .init(
            before: projection.before,
            logicalDiff: diff,
            policy: policy
        ))

        #expect(projection.after.node(for: logicalID(4))?.position == 0)
        #expect(plan.report.plannedOperationCount == 1)
        guard case .create(let creation) = plan.phases[0].operations.first else {
            Issue.record("The sparse source addition must produce one creation")
            return
        }
        #expect(creation.logicalNodeID == logicalID(4))
        #expect(creation.position == 0)
    }

    @Test("Content-only projects title and URL without projecting structure or population")
    func contentOnly() throws {
        let source = try snapshot(source: safari, nodes: [
            folder(1, "Root"),
            folder(2, "Source Parent", parent: 1),
            bookmark(3, "Source Title", parent: 2, url: "https://source.test"),
            bookmark(4, "Source Only", parent: 1, position: 1),
        ])
        let target = try snapshot(source: chrome, nodes: [
            folder(1, "Root"),
            folder(2, "Target Parent", parent: 1),
            bookmark(3, "Target Title", parent: 1, url: "https://target.test"),
            bookmark(5, "Target Only", parent: 1, position: 1),
        ])
        let direction = SynchronizationDirection.oneWay(
            source: safari,
            target: chrome
        )

        let projection = try TargetProjector().project(request: .init(
            sourceSnapshot: source,
            targetSnapshot: target,
            policy: .contentOnly(direction: direction)
        ))
        let diff = try LogicalDiffEngine().diff(request: .init(
            before: projection.before,
            after: projection.after
        ))

        let projected = try #require(projection.after.node(for: logicalID(3)))
        #expect(projected.title == "Source Title")
        #expect(projected.url == URL(string: "https://source.test"))
        #expect(projected.parentID == logicalID(1))
        #expect(projection.after.node(for: logicalID(4)) == nil)
        #expect(projection.after.node(for: logicalID(5)) != nil)
        #expect(diff.changes.map(\.logicalNodeID) == [
            logicalID(2),
            logicalID(3),
            logicalID(3),
        ])
        #expect(diff.changes.allSatisfy {
            switch $0 {
            case .renamed, .urlChanged: true
            default: false
            }
        })
    }

    @Test("A source-only folder hierarchy is projected without inventing parents")
    func sourceOnlyFolders() throws {
        let source = try snapshot(source: safari, nodes: [
            folder(1, "Root"),
            folder(2, "Folder", parent: 1),
            folder(3, "Nested", parent: 2),
            bookmark(4, "Bookmark", parent: 3),
        ])
        let target = try snapshot(source: chrome, nodes: [
            folder(1, "Root"),
        ])
        let direction = SynchronizationDirection.oneWay(
            source: safari,
            target: chrome
        )

        let projection = try TargetProjector().project(request: .init(
            sourceSnapshot: source,
            targetSnapshot: target,
            policy: .additionsOnly(direction: direction)
        ))

        #expect(projectedNodes(projection.after) == source.tree.nodes)
    }

    @Test("Homologous permanent roots retain the target root and project only content")
    func homologousPermanentRoots() throws {
        let source = try snapshot(source: safari, nodes: [
            folder(
                1,
                "Safari Favorites",
                position: 7,
                permanentRootRole: .primaryBookmarks
            ),
            bookmark(2, "Created", parent: 1),
        ])
        let target = try snapshot(source: chrome, nodes: [
            folder(
                1,
                "Bookmarks Bar",
                position: 0,
                permanentRootRole: .primaryBookmarks
            ),
        ])

        let projection = try project(source: source, target: target)
        let diff = try LogicalDiffEngine().diff(request: .init(
            before: projection.before,
            after: projection.after
        ))
        let root = try #require(projection.after.node(for: logicalID(1)))

        #expect(root.title == "Bookmarks Bar")
        #expect(root.position == 0)
        #expect(root.permanentRootRole == .primaryBookmarks)
        #expect(diff.changes.count == 1)
        #expect(diff.changes.first?.logicalNodeID == logicalID(2))
    }

    @Test("Permanent roots without homologues and their subtrees stay independent")
    func nonHomologousPermanentRoots() throws {
        let source = try snapshot(source: safari, nodes: [
            folder(
                1,
                "Favorites",
                permanentRootRole: .primaryBookmarks
            ),
            folder(
                10,
                "Reading List",
                position: 1,
                permanentRootRole: .readingList
            ),
            bookmark(11, "Safari only", parent: 10),
        ])
        let target = try snapshot(source: chrome, nodes: [
            folder(
                1,
                "Bookmarks Bar",
                permanentRootRole: .primaryBookmarks
            ),
            folder(
                20,
                "Mobile Bookmarks",
                position: 1,
                permanentRootRole: .mobileBookmarks
            ),
            bookmark(21, "Chrome only", parent: 20),
        ])

        let projection = try project(source: source, target: target)

        #expect(projection.after.node(for: logicalID(10)) == nil)
        #expect(projection.after.node(for: logicalID(11)) == nil)
        #expect(projection.after.node(for: logicalID(20)) != nil)
        #expect(projection.after.node(for: logicalID(21)) != nil)
    }

    @Test("A permanent root mutation injected through inconsistent identities is rejected")
    func rejectsPermanentRootMutation() throws {
        let source = try snapshot(source: safari, nodes: [
            folder(
                1,
                "Favorites",
                permanentRootRole: .primaryBookmarks
            ),
        ])
        let target = try snapshot(source: chrome, nodes: [
            folder(
                2,
                "Bookmarks Bar",
                permanentRootRole: .primaryBookmarks
            ),
        ])

        #expect(throws: TargetProjectionError.invalidPermanentRootMutation(
            logicalID(1)
        )) {
            _ = try project(source: source, target: target)
        }
    }

    @Test("Projection is deterministic and leaves both snapshots unchanged")
    func deterministic() throws {
        let source = try snapshot(source: safari, nodes: [
            folder(1, "Root"),
            bookmark(2, "Bookmark", parent: 1),
        ])
        let target = try snapshot(source: chrome, nodes: [
            folder(1, "Old Root"),
        ])
        let originalSource = source
        let originalTarget = target
        let request = try request(source: source, target: target)
        let projector = TargetProjector()

        let first = try projector.project(request: request)
        let second = try projector.project(request: request)

        #expect(first == second)
        #expect(source == originalSource)
        #expect(target == originalTarget)
        requireSendable(projector)
        requireSendable(first)
    }

    private var safari: BSESourceID { sourceID(1) }
    private var chrome: BSESourceID { sourceID(2) }

    private func project(
        source: LogicalSnapshot,
        target: LogicalSnapshot
    ) throws -> TargetProjection {
        try TargetProjector().project(request: request(
            source: source,
            target: target
        ))
    }

    private func request(
        source: LogicalSnapshot,
        target: LogicalSnapshot
    ) throws -> ProjectionRequest {
        let direction = SynchronizationDirection.oneWay(
            source: source.source,
            target: target.source
        )
        return try ProjectionRequest(
            sourceSnapshot: source,
            targetSnapshot: target,
            policy: .allChanges(direction: direction)
        )
    }

    private func snapshot(
        source: BSESourceID,
        nodes: [BSENode]
    ) throws -> LogicalSnapshot {
        LogicalSnapshot(
            source: source,
            capturedAt: Date(timeIntervalSince1970: 1_000),
            tree: try BSETree(nodes: nodes)
        )
    }

    private func folder(
        _ id: Int,
        _ title: String,
        parent: Int? = nil,
        position: Int = 0,
        permanentRootRole: PermanentRootRole? = nil
    ) throws -> BSENode {
        try BSENode(
            logicalID: logicalID(id),
            kind: .folder,
            permanentRootRole: permanentRootRole,
            title: title,
            parentID: parent.map(logicalID),
            position: position
        )
    }

    private func bookmark(
        _ id: Int,
        _ title: String,
        parent: Int,
        position: Int = 0,
        url: String = "https://example.test"
    ) throws -> BSENode {
        try BSENode(
            logicalID: logicalID(id),
            kind: .bookmark,
            title: title,
            parentID: logicalID(parent),
            position: position,
            url: URL(string: url)
        )
    }

    private func projectedNodes(_ graph: LogicalStateGraph) -> [BSENode] {
        graph.nodes.compactMap { state in
            guard let kind = state.kind,
                  let title = state.title,
                  let position = state.position else {
                return nil
            }
            return try? BSENode(
                logicalID: state.logicalNodeID,
                kind: kind,
                permanentRootRole: state.permanentRootRole,
                title: title,
                parentID: state.parentID,
                position: position,
                url: state.url
            )
        }
    }

    private func logicalID(_ value: Int) -> LogicalNodeID {
        LogicalNodeID(UUID(uuidString: String(
            format: "D0000000-0000-0000-0000-%012d",
            value
        ))!)
    }

    private func sourceID(_ value: Int) -> BSESourceID {
        BSESourceID(UUID(uuidString: String(
            format: "E0000000-0000-0000-0000-%012d",
            value
        ))!)
    }

    private func requireSendable<T: Sendable>(_ value: T) { _ = value }
}
