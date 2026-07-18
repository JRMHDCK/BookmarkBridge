//
//  IdentityReconciliationEngineTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("BSE Identity Reconciliation Engine")
struct IdentityReconciliationEngineTests {
    @Test("Reuses a durable identity already observed in the Baseline")
    func reuseIdentity() throws {
        let sourceID = try ReconciliationTestSupport.sourceID(1)
        let provisionalID = try ReconciliationTestSupport.provisionalID(1)
        let durableID = try ReconciliationTestSupport.durableID(1)
        let snapshot = try ReconciliationTestSupport.snapshot(
            source: sourceID,
            capturedAt: ReconciliationTestSupport.date(20),
            nodes: [ReconciliationTestSupport.folder(id: provisionalID)]
        )
        let baseline = try ReconciliationTestSupport.baseline(
            records: [ReconciliationTestSupport.record(
                id: durableID,
                observations: [ReconciliationTestSupport.observation(
                    source: sourceID,
                    provisional: provisionalID,
                    first: ReconciliationTestSupport.date(10),
                    last: ReconciliationTestSupport.date(10)
                )]
            )]
        )
        let provider = TestIdentityProvider(ids: [])
        let engine = IdentityReconciliationEngine(
            identityProvider: provider,
            matchingPolicy: StrictIdentityMatchingPolicy(),
            snapshotBuilder: LogicalSnapshotBuilder()
        )

        let result = try engine.reconcile(request: IdentityReconciliationRequest(
            baseline: baseline,
            snapshots: [snapshot],
            matchingGroups: [ReconciliationTestSupport.group(
                members: [(sourceID, provisionalID)],
                result: .noMatch(reason: .noCandidates)
            )]
        ))

        #expect(result.logicalSnapshots.first?.tree.nodes.first?.logicalID == durableID)
        #expect(result.report.reusedIdentities.map(\.logicalNodeID) == [durableID])
        #expect(result.report.createdIdentities.isEmpty)
        #expect(provider.callCount == 0)
        let command = try #require(result.baselineCommands.first)
        guard case .updateObservation(let update) = command else {
            Issue.record("Expected updateObservation")
            return
        }
        #expect(update.logicalNodeID == durableID)
        #expect(update.observation.lastObservedAt == snapshot.capturedAt)
    }

    @Test("Creates one identity and an exact create command")
    func createIdentity() throws {
        let sourceID = try ReconciliationTestSupport.sourceID(1)
        let provisionalID = try ReconciliationTestSupport.provisionalID(1)
        let durableID = try ReconciliationTestSupport.durableID(1)
        let snapshot = try ReconciliationTestSupport.snapshot(
            source: sourceID,
            nodes: [ReconciliationTestSupport.folder(id: provisionalID)]
        )
        let provider = TestIdentityProvider(ids: [durableID])
        let engine = ReconciliationTestSupport.engine(provider: provider)

        let result = try engine.reconcile(request: IdentityReconciliationRequest(
            baseline: ReconciliationTestSupport.emptyBaseline(),
            snapshots: [snapshot],
            matchingGroups: [ReconciliationTestSupport.group(
                members: [(sourceID, provisionalID)],
                result: .noMatch(reason: .noCandidates)
            )]
        ))

        #expect(provider.callCount == 1)
        #expect(result.report.createdIdentities.map(\.logicalNodeID) == [durableID])
        #expect(result.logicalSnapshots.first?.tree.nodes.first?.logicalID == durableID)
        guard case .createIdentity(let create) = try #require(result.baselineCommands.first) else {
            Issue.record("Expected createIdentity")
            return
        }
        #expect(create.logicalNodeID == durableID)
        #expect(create.observations.count == 1)
        #expect(create.observations[0].sourceID == sourceID)
        #expect(create.observations[0].provisionalLogicalID == provisionalID)
        #expect(create.observations[0].recognitionArtifacts.isEmpty)
        #expect(create.observations[0].firstObservedAt == snapshot.capturedAt)
    }

    @Test("One matched object across multiple sources receives one durable ID")
    func multipleSourcesAndObservations() throws {
        let leftSource = try ReconciliationTestSupport.sourceID(1)
        let rightSource = try ReconciliationTestSupport.sourceID(2)
        let leftID = try ReconciliationTestSupport.provisionalID(1)
        let rightID = try ReconciliationTestSupport.provisionalID(2)
        let durableID = try ReconciliationTestSupport.durableID(1)
        let left = try ReconciliationTestSupport.snapshot(
            source: leftSource,
            nodes: [ReconciliationTestSupport.folder(id: leftID)]
        )
        let right = try ReconciliationTestSupport.snapshot(
            source: rightSource,
            nodes: [ReconciliationTestSupport.folder(id: rightID)]
        )
        let engine = ReconciliationTestSupport.engine(
            provider: TestIdentityProvider(ids: [durableID])
        )

        let result = try engine.reconcile(request: IdentityReconciliationRequest(
            baseline: ReconciliationTestSupport.emptyBaseline(),
            snapshots: [right, left],
            matchingGroups: [ReconciliationTestSupport.group(
                members: [(rightSource, rightID), (leftSource, leftID)],
                result: .match(candidateID: rightID, reason: .sameBookmarkURL)
            )]
        ))

        #expect(result.logicalSnapshots.count == 2)
        #expect(result.logicalSnapshots.allSatisfy {
            $0.tree.nodes.first?.logicalID == durableID
        })
        guard case .createIdentity(let create) = try #require(result.baselineCommands.first) else {
            Issue.record("Expected createIdentity")
            return
        }
        #expect(create.observations.map(\.sourceID) == [leftSource, rightSource])
        #expect(result.report.statistics.createdIdentityCount == 1)
        #expect(result.report.statistics.logicalSnapshotCount == 2)
    }

    @Test("Ambiguity creates no identity, command, or partial logical snapshot")
    func ambiguity() throws {
        let sourceID = try ReconciliationTestSupport.sourceID(1)
        let provisionalID = try ReconciliationTestSupport.provisionalID(1)
        let candidates = [
            try ReconciliationTestSupport.durableID(1),
            try ReconciliationTestSupport.durableID(2),
        ]
        let snapshot = try ReconciliationTestSupport.snapshot(
            source: sourceID,
            nodes: [ReconciliationTestSupport.folder(id: provisionalID)]
        )
        let provider = TestIdentityProvider(ids: [try ReconciliationTestSupport.durableID(3)])
        let engine = ReconciliationTestSupport.engine(provider: provider)

        let result = try engine.reconcile(request: IdentityReconciliationRequest(
            baseline: ReconciliationTestSupport.emptyBaseline(),
            snapshots: [snapshot],
            matchingGroups: [ReconciliationTestSupport.group(
                members: [(sourceID, provisionalID)],
                result: .ambiguous(
                    candidateIDs: Array(candidates.reversed()),
                    reason: .ambiguousCandidates(count: 2)
                )
            )]
        ))

        #expect(result.baselineCommands.isEmpty)
        #expect(result.logicalSnapshots.isEmpty)
        #expect(provider.callCount == 0)
        #expect(result.report.ambiguities.first?.candidateIDs == candidates)
        #expect(result.report.unresolvedObjects == [IdentityNodeReference(
            sourceID: sourceID,
            provisionalLogicalID: provisionalID
        )])
    }

    @Test("Already satisfied reuse emits no unnecessary Baseline command")
    func noUnnecessaryCommand() throws {
        let sourceID = try ReconciliationTestSupport.sourceID(1)
        let provisionalID = try ReconciliationTestSupport.provisionalID(1)
        let durableID = try ReconciliationTestSupport.durableID(1)
        let capturedAt = ReconciliationTestSupport.date(10)
        let snapshot = try ReconciliationTestSupport.snapshot(
            source: sourceID,
            capturedAt: capturedAt,
            nodes: [ReconciliationTestSupport.folder(id: provisionalID)]
        )
        let baseline = try ReconciliationTestSupport.baseline(records: [
            ReconciliationTestSupport.record(
                id: durableID,
                observations: [ReconciliationTestSupport.observation(
                    source: sourceID,
                    provisional: provisionalID,
                    first: capturedAt,
                    last: capturedAt
                )]
            ),
        ])
        let engine = ReconciliationTestSupport.engine(provider: TestIdentityProvider(ids: []))

        let result = try engine.reconcile(request: IdentityReconciliationRequest(
            baseline: baseline,
            snapshots: [snapshot],
            matchingGroups: [ReconciliationTestSupport.group(
                members: [(sourceID, provisionalID)],
                result: .noMatch(reason: .noCandidates)
            )]
        ))

        #expect(result.baselineCommands.isEmpty)
        #expect(result.logicalSnapshots.count == 1)
    }

    @Test("Archived reuse emits reactivation before observation update")
    func reactivationCommandsHaveExactRevisions() throws {
        let sourceID = try ReconciliationTestSupport.sourceID(1)
        let provisionalID = try ReconciliationTestSupport.provisionalID(1)
        let durableID = try ReconciliationTestSupport.durableID(1)
        let snapshot = try ReconciliationTestSupport.snapshot(
            source: sourceID,
            capturedAt: ReconciliationTestSupport.date(20),
            nodes: [ReconciliationTestSupport.folder(id: provisionalID)]
        )
        let record = try ReconciliationTestSupport.record(
            id: durableID,
            state: .archived,
            observations: [ReconciliationTestSupport.observation(
                source: sourceID,
                provisional: provisionalID
            )]
        )
        let engine = ReconciliationTestSupport.engine(provider: TestIdentityProvider(ids: []))

        let result = try engine.reconcile(request: IdentityReconciliationRequest(
            baseline: ReconciliationTestSupport.baseline(records: [record]),
            snapshots: [snapshot],
            matchingGroups: [ReconciliationTestSupport.group(
                members: [(sourceID, provisionalID)],
                result: .noMatch(reason: .noCandidates)
            )]
        ))

        #expect(result.baselineCommands.count == 2)
        guard case .reactivateIdentity(let reactivate) = result.baselineCommands[0],
              case .updateObservation(let update) = result.baselineCommands[1] else {
            Issue.record("Expected reactivate then update")
            return
        }
        #expect(reactivate.expectedIdentityRevision.rawValue == 1)
        #expect(update.expectedIdentityRevision.rawValue == 2)
    }

    @Test("Original snapshots remain bit-for-bit value-equal")
    func snapshotsAreNeverMutated() throws {
        let sourceID = try ReconciliationTestSupport.sourceID(1)
        let provisionalID = try ReconciliationTestSupport.provisionalID(1)
        let snapshot = try ReconciliationTestSupport.snapshot(
            source: sourceID,
            nodes: [ReconciliationTestSupport.folder(id: provisionalID)]
        )
        let before = snapshot
        let engine = ReconciliationTestSupport.engine(
            provider: TestIdentityProvider(ids: [try ReconciliationTestSupport.durableID(1)])
        )

        _ = try engine.reconcile(request: IdentityReconciliationRequest(
            baseline: ReconciliationTestSupport.emptyBaseline(),
            snapshots: [snapshot],
            matchingGroups: [ReconciliationTestSupport.group(
                members: [(sourceID, provisionalID)],
                result: .noMatch(reason: .noCandidates)
            )]
        ))

        #expect(snapshot == before)
    }

    @Test("Injected policies control reuse or creation without engine heuristics")
    func multiplePolicies() throws {
        let sourceID = try ReconciliationTestSupport.sourceID(1)
        let provisionalID = try ReconciliationTestSupport.provisionalID(1)
        let existingID = try ReconciliationTestSupport.durableID(1)
        let createdID = try ReconciliationTestSupport.durableID(2)
        let snapshot = try ReconciliationTestSupport.snapshot(
            source: sourceID,
            nodes: [ReconciliationTestSupport.folder(id: provisionalID)]
        )
        let baseline = try ReconciliationTestSupport.baseline(records: [
            ReconciliationTestSupport.record(id: existingID, observations: []),
        ])
        let request = IdentityReconciliationRequest(
            baseline: baseline,
            snapshots: [snapshot],
            matchingGroups: [ReconciliationTestSupport.group(
                members: [(sourceID, provisionalID)],
                result: .noMatch(reason: .noCandidates)
            )]
        )
        let reuseEngine = IdentityReconciliationEngine(
            identityProvider: TestIdentityProvider(ids: []),
            matchingPolicy: FixedIdentityPolicy(decision: .reuse(existingID)),
            snapshotBuilder: LogicalSnapshotBuilder()
        )
        let createEngine = IdentityReconciliationEngine(
            identityProvider: TestIdentityProvider(ids: [createdID]),
            matchingPolicy: FixedIdentityPolicy(decision: .create),
            snapshotBuilder: LogicalSnapshotBuilder()
        )

        #expect(try reuseEngine.reconcile(request: request)
            .report.reusedIdentities.first?.logicalNodeID == existingID)
        #expect(try createEngine.reconcile(request: request)
            .report.createdIdentities.first?.logicalNodeID == createdID)
    }

    @Test("Same dependencies and input produce the same complete result")
    func deterministic() throws {
        let sourceID = try ReconciliationTestSupport.sourceID(1)
        let provisionalID = try ReconciliationTestSupport.provisionalID(1)
        let durableID = try ReconciliationTestSupport.durableID(1)
        let snapshot = try ReconciliationTestSupport.snapshot(
            source: sourceID,
            nodes: [ReconciliationTestSupport.folder(id: provisionalID)]
        )
        let request = IdentityReconciliationRequest(
            baseline: try ReconciliationTestSupport.emptyBaseline(),
            snapshots: [snapshot],
            matchingGroups: [ReconciliationTestSupport.group(
                members: [(sourceID, provisionalID)],
                result: .noMatch(reason: .noCandidates)
            )]
        )
        let first = try ReconciliationTestSupport.engine(
            provider: TestIdentityProvider(ids: [durableID])
        ).reconcile(request: request)
        let second = try ReconciliationTestSupport.engine(
            provider: TestIdentityProvider(ids: [durableID])
        ).reconcile(request: request)

        #expect(first == second)
    }

    @Test("Models and dependency boundaries satisfy Sendable")
    func strictConcurrency() throws {
        let request = IdentityReconciliationRequest(
            baseline: try ReconciliationTestSupport.emptyBaseline(),
            snapshots: [],
            matchingGroups: []
        )
        let engine = ReconciliationTestSupport.engine(provider: TestIdentityProvider(ids: []))

        requireSendable(request)
        requireSendable(engine)
        requireSendable(StrictIdentityMatchingPolicy())
        requireSendable(LogicalSnapshotBuilder())
    }

    private func requireSendable<T: Sendable>(_ value: T) { _ = value }
}

nonisolated enum ReconciliationTestSupport {
    static func baselineID() -> BaselineID {
        BaselineID(UUID(uuidString: "93000000-0000-0000-0000-000000000001")!)
    }

    static func sourceID(_ value: Int) throws -> BSESourceID {
        let string = String(format: "94000000-0000-0000-0000-%012d", value)
        return BSESourceID(try #require(UUID(uuidString: string)))
    }

    static func provisionalID(_ value: Int) throws -> LogicalNodeID {
        let string = String(format: "95000000-0000-0000-0000-%012d", value)
        return LogicalNodeID(try #require(UUID(uuidString: string)))
    }

    static func durableID(_ value: Int) throws -> LogicalNodeID {
        let string = String(format: "96000000-0000-0000-0000-%012d", value)
        return LogicalNodeID(try #require(UUID(uuidString: string)))
    }

    static func date(_ offset: TimeInterval = 10) -> Date {
        Date(timeIntervalSince1970: 1_800_000_000 + offset)
    }

    static func folder(
        id: LogicalNodeID,
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

    static func bookmark(
        id: LogicalNodeID,
        parentID: LogicalNodeID,
        title: String = "Bookmark",
        position: Int = 0
    ) throws -> BSENode {
        try BSENode(
            logicalID: id,
            kind: .bookmark,
            title: title,
            parentID: parentID,
            position: position,
            url: URL(string: "https://example.com")
        )
    }

    static func snapshot(
        source: BSESourceID,
        capturedAt: Date = date(),
        nodes: [BSENode]
    ) throws -> BSESnapshot {
        BSESnapshot(
            source: source,
            capturedAt: capturedAt,
            tree: try BSETree(nodes: nodes)
        )
    }

    static func observation(
        source: BSESourceID,
        provisional: LogicalNodeID,
        first: Date = date(10),
        last: Date = date(10)
    ) throws -> BaselineObservation {
        try BaselineObservation(
            sourceID: source,
            provisionalLogicalID: provisional,
            recognitionArtifacts: [],
            firstObservedAt: first,
            lastObservedAt: last,
            presence: .present
        )
    }

    static func record(
        id: LogicalNodeID,
        state: IdentityRecordState = .active,
        observations: [BaselineObservation]
    ) throws -> IdentityRecord {
        try IdentityRecord(
            logicalNodeID: id,
            revision: IdentityRevision(1),
            state: state,
            observations: observations,
            metadata: IdentityRecordMetadata(
                createdInBaselineRevision: BaselineRevision(1),
                lastChangedInBaselineRevision: BaselineRevision(1)
            )
        )
    }

    static func baseline(records: [IdentityRecord]) throws -> Baseline {
        try Baseline(
            baselineID: baselineID(),
            schemaVersion: .current,
            revision: BaselineRevision(records.isEmpty ? 0 : 1),
            identityRecords: records
        )
    }

    static func emptyBaseline() throws -> Baseline {
        try Baseline.empty(baselineID: baselineID())
    }

    static func group(
        members: [(BSESourceID, LogicalNodeID)],
        result: MatchingResult
    ) -> IdentityMatchingGroup {
        IdentityMatchingGroup(
            members: members.map {
                IdentityNodeReference(sourceID: $0.0, provisionalLogicalID: $0.1)
            },
            matchingResult: result
        )
    }

    static func engine(provider: TestIdentityProvider) -> IdentityReconciliationEngine {
        IdentityReconciliationEngine(
            identityProvider: provider,
            matchingPolicy: StrictIdentityMatchingPolicy(),
            snapshotBuilder: LogicalSnapshotBuilder()
        )
    }
}

final class TestIdentityProvider: IdentityProvider, @unchecked Sendable {
    enum ProviderError: Error { case exhausted }

    private let lock = NSLock()
    private var ids: [LogicalNodeID]
    private var storedCallCount = 0

    init(ids: [LogicalNodeID]) { self.ids = ids }

    func nextLogicalNodeID() throws -> LogicalNodeID {
        lock.lock()
        defer { lock.unlock() }
        storedCallCount += 1
        guard !ids.isEmpty else { throw ProviderError.exhausted }
        return ids.removeFirst()
    }

    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedCallCount
    }
}

nonisolated struct FixedIdentityPolicy: IdentityMatchingPolicy {
    let decision: IdentityMatchingDecision

    func decide(for context: IdentityMatchingContext) throws -> IdentityMatchingDecision {
        decision
    }
}
