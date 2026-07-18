//
//  LogicalStateBuilderTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("BSE Logical State Builder")
struct LogicalStateBuilderTests {
    @Test("Empty inputs produce an empty graph")
    func emptyGraph() throws {
        let graph = try LogicalStateBuilder().build(
            request: LogicalStateBuildingRequest(
                baseline: LogicalStateTestSupport.emptyBaseline(),
                logicalSnapshots: []
            )
        )

        #expect(graph.nodes.isEmpty)
        #expect(graph.report.logicalNodeCount == 0)
        #expect(graph.report.observationCount == 0)
    }

    @Test("One snapshot node retains its complete structure")
    func oneNode() throws {
        let sourceID = LogicalStateTestSupport.sourceID(1)
        let logicalID = LogicalStateTestSupport.logicalID(1)
        let graph = try LogicalStateBuilder().build(
            request: LogicalStateBuildingRequest(
                baseline: LogicalStateTestSupport.emptyBaseline(),
                logicalSnapshots: [LogicalStateTestSupport.snapshot(
                    sourceID: sourceID,
                    nodes: [LogicalStateTestSupport.folder(id: logicalID)]
                )]
            )
        )
        let node = try #require(graph.node(for: logicalID))

        #expect(node.kind == .folder)
        #expect(node.title == "Folder 1")
        #expect(node.position == 0)
        #expect(node.lifecycle == .unregistered)
        #expect(node.observations.count == 1)
        #expect(node.observations[0].snapshotNode?.logicalID == logicalID)
        #expect(node.observations[0].baselineObservation == nil)
    }

    @Test("A complete hierarchy preserves parent and position")
    func completeHierarchy() throws {
        let rootID = LogicalStateTestSupport.logicalID(1)
        let childID = LogicalStateTestSupport.logicalID(2)
        let graph = try LogicalStateBuilder().build(
            request: LogicalStateBuildingRequest(
                baseline: LogicalStateTestSupport.emptyBaseline(),
                logicalSnapshots: [LogicalStateTestSupport.snapshot(
                    sourceID: LogicalStateTestSupport.sourceID(1),
                    nodes: [
                        LogicalStateTestSupport.folder(id: rootID),
                        LogicalStateTestSupport.bookmark(
                            id: childID,
                            parentID: rootID,
                            position: 3
                        ),
                    ]
                )]
            )
        )
        let child = try #require(graph.node(for: childID))

        #expect(child.kind == .bookmark)
        #expect(child.parentID == rootID)
        #expect(child.position == 3)
        #expect(child.url?.absoluteString == "https://example.com/2")
    }

    @Test("Graph validation rejects a missing parent")
    func missingParent() throws {
        let logicalID = LogicalStateTestSupport.logicalID(1)
        let missingParentID = LogicalStateTestSupport.logicalID(2)
        let node = try LogicalNodeState(
            logicalNodeID: logicalID,
            kind: .folder,
            title: "Orphan",
            url: nil,
            parentID: missingParentID,
            position: 0,
            lifecycle: .unregistered,
            observations: []
        )

        #expect(throws: LogicalStateBuildingError.missingParent(
            logicalNodeID: logicalID,
            parentID: missingParentID
        )) {
            _ = try LogicalStateGraph(
                nodes: [node],
                report: LogicalStateTestSupport.emptyReport
            )
        }
    }

    @Test("The same logical node repeated for one source is rejected")
    func duplicateLogicalNode() throws {
        let sourceID = LogicalStateTestSupport.sourceID(1)
        let logicalID = LogicalStateTestSupport.logicalID(1)
        let snapshots = try [1, 2].map { _ in
            try LogicalStateTestSupport.snapshot(
                sourceID: sourceID,
                nodes: [LogicalStateTestSupport.folder(id: logicalID)]
            )
        }

        #expect(throws: LogicalStateBuildingError.duplicateLogicalNode(
            logicalNodeID: logicalID,
            sourceID: sourceID
        )) {
            _ = try LogicalStateBuilder().build(
                request: LogicalStateBuildingRequest(
                    baseline: LogicalStateTestSupport.emptyBaseline(),
                    logicalSnapshots: snapshots
                )
            )
        }
    }

    @Test("Identical representations from multiple sources merge observations")
    func multipleSources() throws {
        let logicalID = LogicalStateTestSupport.logicalID(1)
        let sources = [
            LogicalStateTestSupport.sourceID(1),
            LogicalStateTestSupport.sourceID(2),
        ]
        let baseline = try LogicalStateTestSupport.baseline(records: [
            LogicalStateTestSupport.record(
                logicalID: logicalID,
                observations: try sources.enumerated().map { index, sourceID in
                    try LogicalStateTestSupport.observation(
                        sourceID: sourceID,
                        provisionalID: LogicalStateTestSupport.logicalID(100 + index)
                    )
                }
            ),
        ])
        let snapshots = try sources.map {
            try LogicalStateTestSupport.snapshot(
                sourceID: $0,
                nodes: [LogicalStateTestSupport.folder(id: logicalID)]
            )
        }

        let graph = try LogicalStateBuilder().build(
            request: LogicalStateBuildingRequest(
                baseline: baseline,
                logicalSnapshots: snapshots
            )
        )
        let node = try #require(graph.node(for: logicalID))

        #expect(node.lifecycle == .registered(.active))
        #expect(node.observations.count == 2)
        #expect(node.observations.allSatisfy {
            $0.snapshotNode != nil && $0.baselineObservation != nil
        })
        #expect(graph.report.observationCount == 2)
    }

    @Test("A Baseline-only identity preserves metadata without invented structure")
    func baselineOnlyIdentity() throws {
        let logicalID = LogicalStateTestSupport.logicalID(1)
        let sourceID = LogicalStateTestSupport.sourceID(1)
        let baseline = try LogicalStateTestSupport.baseline(records: [
            LogicalStateTestSupport.record(
                logicalID: logicalID,
                state: .archived,
                observations: [LogicalStateTestSupport.observation(
                    sourceID: sourceID,
                    provisionalID: LogicalStateTestSupport.logicalID(101)
                )]
            ),
        ])

        let graph = try LogicalStateBuilder().build(
            request: LogicalStateBuildingRequest(
                baseline: baseline,
                logicalSnapshots: []
            )
        )
        let node = try #require(graph.node(for: logicalID))

        #expect(node.kind == nil)
        #expect(node.title == nil)
        #expect(node.position == nil)
        #expect(node.lifecycle == .registered(.archived))
        #expect(node.observations[0].baselineObservation?.sourceID == sourceID)
        #expect(node.observations[0].snapshotNode == nil)
        #expect(graph.report.baselineOnlyNodeCount == 1)
    }

    @Test("Divergent source representations are never resolved implicitly")
    func inconsistentGraph() throws {
        let logicalID = LogicalStateTestSupport.logicalID(1)
        let first = try LogicalStateTestSupport.snapshot(
            sourceID: LogicalStateTestSupport.sourceID(1),
            nodes: [LogicalStateTestSupport.folder(id: logicalID, title: "First")]
        )
        let second = try LogicalStateTestSupport.snapshot(
            sourceID: LogicalStateTestSupport.sourceID(2),
            nodes: [LogicalStateTestSupport.folder(id: logicalID, title: "Second")]
        )

        #expect(throws: LogicalStateBuildingError.inconsistentGraph(logicalID)) {
            _ = try LogicalStateBuilder().build(
                request: LogicalStateBuildingRequest(
                    baseline: LogicalStateTestSupport.emptyBaseline(),
                    logicalSnapshots: [first, second]
                )
            )
        }
    }

    @Test("Input ordering cannot affect graph or observation ordering")
    func deterministic() throws {
        let logicalID = LogicalStateTestSupport.logicalID(1)
        let snapshots = try [1, 2].map {
            try LogicalStateTestSupport.snapshot(
                sourceID: LogicalStateTestSupport.sourceID($0),
                nodes: [LogicalStateTestSupport.folder(id: logicalID)]
            )
        }
        let request = LogicalStateBuildingRequest(
            baseline: try LogicalStateTestSupport.emptyBaseline(),
            logicalSnapshots: snapshots
        )

        let first = try LogicalStateBuilder().build(request: request)
        let second = try LogicalStateBuilder().build(
            request: LogicalStateBuildingRequest(
                baseline: request.baseline,
                logicalSnapshots: Array(snapshots.reversed())
            )
        )

        #expect(first == second)
    }

    @Test("Graph Codable round-trip preserves validated invariants")
    func codableRoundTrip() throws {
        let graph = try LogicalStateBuilder().build(
            request: LogicalStateBuildingRequest(
                baseline: LogicalStateTestSupport.emptyBaseline(),
                logicalSnapshots: [LogicalStateTestSupport.snapshot(
                    sourceID: LogicalStateTestSupport.sourceID(1),
                    nodes: [LogicalStateTestSupport.folder(
                        id: LogicalStateTestSupport.logicalID(1)
                    )]
                )]
            )
        )

        let data = try JSONEncoder().encode(graph)
        let decoded = try JSONDecoder().decode(LogicalStateGraph.self, from: data)

        #expect(decoded == graph)
    }

    @Test("Builder and graph models satisfy Swift Concurrency")
    func strictConcurrency() throws {
        let request = LogicalStateBuildingRequest(
            baseline: try LogicalStateTestSupport.emptyBaseline(),
            logicalSnapshots: []
        )
        let graph = try LogicalStateBuilder().build(request: request)

        requireSendable(LogicalStateBuilder())
        requireSendable(request)
        requireSendable(graph)
    }

    private func requireSendable<T: Sendable>(_ value: T) { _ = value }
}

private enum LogicalStateTestSupport {
    static let emptyReport = LogicalStateBuildingReport(
        baselineIdentityCount: 0,
        snapshotCount: 0,
        snapshotNodeCount: 0,
        logicalNodeCount: 0,
        structurallyAvailableNodeCount: 0,
        baselineOnlyNodeCount: 0,
        unregisteredNodeCount: 0,
        observationCount: 0
    )

    static func emptyBaseline() throws -> Baseline {
        try Baseline.empty(baselineID: BaselineID(uuid(900)))
    }

    static func baseline(records: [IdentityRecord]) throws -> Baseline {
        try Baseline(
            baselineID: BaselineID(uuid(900)),
            schemaVersion: .current,
            revision: BaselineRevision(records.isEmpty ? 0 : 1),
            identityRecords: records
        )
    }

    static func record(
        logicalID: LogicalNodeID,
        state: IdentityRecordState = .active,
        observations: [BaselineObservation]
    ) throws -> IdentityRecord {
        try IdentityRecord(
            logicalNodeID: logicalID,
            revision: IdentityRevision(1),
            state: state,
            observations: observations,
            metadata: IdentityRecordMetadata(
                createdInBaselineRevision: BaselineRevision(1),
                lastChangedInBaselineRevision: BaselineRevision(1)
            )
        )
    }

    static func observation(
        sourceID: BSESourceID,
        provisionalID: LogicalNodeID
    ) throws -> BaselineObservation {
        try BaselineObservation(
            sourceID: sourceID,
            provisionalLogicalID: provisionalID,
            recognitionArtifacts: [],
            firstObservedAt: Date(timeIntervalSince1970: 10),
            lastObservedAt: Date(timeIntervalSince1970: 10),
            presence: .present
        )
    }

    static func snapshot(
        sourceID: BSESourceID,
        nodes: [BSENode]
    ) throws -> LogicalSnapshot {
        LogicalSnapshot(
            source: sourceID,
            capturedAt: Date(timeIntervalSince1970: 20),
            tree: try BSETree(nodes: nodes)
        )
    }

    static func folder(
        id: LogicalNodeID,
        title: String? = nil,
        parentID: LogicalNodeID? = nil,
        position: Int = 0
    ) throws -> BSENode {
        try BSENode(
            logicalID: id,
            kind: .folder,
            title: title ?? "Folder \(id.rawValue.uuidString.suffix(1))",
            parentID: parentID,
            position: position
        )
    }

    static func bookmark(
        id: LogicalNodeID,
        parentID: LogicalNodeID,
        position: Int
    ) throws -> BSENode {
        try BSENode(
            logicalID: id,
            kind: .bookmark,
            title: "Bookmark",
            parentID: parentID,
            position: position,
            url: URL(string: "https://example.com/\(id.rawValue.uuidString.suffix(1))")
        )
    }

    static func sourceID(_ value: Int) -> BSESourceID {
        BSESourceID(uuid(value))
    }

    static func logicalID(_ value: Int) -> LogicalNodeID {
        LogicalNodeID(uuid(value))
    }

    private static func uuid(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}
