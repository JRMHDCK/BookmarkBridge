//
//  MatchingPipelineTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("BSE Matching Pipeline")
struct MatchingPipelineTests {
    @Test("An empty persisted Baseline completes one no-op transaction")
    func emptyBaseline() async throws {
        let baseline = try PipelineTestSupport.emptyBaseline()
        let repository = PipelineTestRepository(baseline: baseline)
        let pipeline = PipelineTestSupport.pipeline(
            repository: repository,
            provider: PipelineTestIdentityProvider(ids: [])
        )

        let result = try await pipeline.execute(
            request: MatchingPipelineRequest(snapshots: [])
        )

        #expect(result.baselineBefore == baseline)
        #expect(result.baselineAfter == baseline)
        #expect(result.logicalSnapshots.isEmpty)
        #expect(result.pipelineReport.baselineMutationCount == 0)
        #expect(!result.pipelineReport.baselineTransactionPersisted)
        #expect(await repository.applyCount == 1)
    }

    @Test("An unchanged existing observation emits no Baseline mutation")
    func existingBaselineWithoutModification() async throws {
        let sourceID = PipelineTestSupport.sourceID(1)
        let provisionalID = PipelineTestSupport.logicalID(1)
        let durableID = PipelineTestSupport.logicalID(100)
        let capturedAt = PipelineTestSupport.date(10)
        let observation = try PipelineTestSupport.observation(
            sourceID: sourceID,
            provisionalID: provisionalID,
            first: capturedAt,
            last: capturedAt
        )
        let baseline = try PipelineTestSupport.baseline(
            records: [PipelineTestSupport.record(
                logicalID: durableID,
                observations: [observation]
            )]
        )
        let repository = PipelineTestRepository(baseline: baseline)
        let provider = PipelineTestIdentityProvider(ids: [])
        let snapshot = try PipelineTestSupport.snapshot(
            sourceID: sourceID,
            capturedAt: capturedAt,
            nodeID: provisionalID
        )

        let result = try await PipelineTestSupport.pipeline(
            repository: repository,
            provider: provider
        ).execute(request: MatchingPipelineRequest(snapshots: [snapshot]))

        #expect(result.baselineAfter == baseline)
        #expect(result.logicalSnapshots.first?.tree.nodes.first?.logicalID == durableID)
        #expect(result.reconciliationReport.reusedIdentities.count == 1)
        #expect(result.pipelineReport.baselineMutationCount == 0)
        #expect(provider.callCount == 0)
    }

    @Test("A new occurrence creates one durable identity")
    func newIdentity() async throws {
        let baseline = try PipelineTestSupport.emptyBaseline()
        let repository = PipelineTestRepository(baseline: baseline)
        let durableID = PipelineTestSupport.logicalID(100)
        let snapshot = try PipelineTestSupport.snapshot(
            sourceID: PipelineTestSupport.sourceID(1),
            nodeID: PipelineTestSupport.logicalID(1)
        )

        let result = try await PipelineTestSupport.pipeline(
            repository: repository,
            provider: PipelineTestIdentityProvider(ids: [durableID])
        ).execute(request: MatchingPipelineRequest(snapshots: [snapshot]))

        #expect(result.baselineBefore == baseline)
        #expect(result.baselineAfter.identityRecords.map(\.logicalNodeID) == [durableID])
        #expect(result.logicalSnapshots.first?.tree.nodes.first?.logicalID == durableID)
        #expect(result.reconciliationReport.createdIdentities.count == 1)
        #expect(result.pipelineReport.baselineMutationCount == 1)
        #expect(result.pipelineReport.baselineTransactionPersisted)
    }

    @Test("A known occurrence reuses its durable identity")
    func reuseIdentity() async throws {
        let sourceID = PipelineTestSupport.sourceID(1)
        let provisionalID = PipelineTestSupport.logicalID(1)
        let durableID = PipelineTestSupport.logicalID(100)
        let baseline = try PipelineTestSupport.baseline(records: [
            PipelineTestSupport.record(
                logicalID: durableID,
                observations: [PipelineTestSupport.observation(
                    sourceID: sourceID,
                    provisionalID: provisionalID,
                    first: PipelineTestSupport.date(10),
                    last: PipelineTestSupport.date(10)
                )]
            ),
        ])
        let repository = PipelineTestRepository(baseline: baseline)
        let snapshot = try PipelineTestSupport.snapshot(
            sourceID: sourceID,
            capturedAt: PipelineTestSupport.date(20),
            nodeID: provisionalID
        )

        let result = try await PipelineTestSupport.pipeline(
            repository: repository,
            provider: PipelineTestIdentityProvider(ids: [])
        ).execute(request: MatchingPipelineRequest(snapshots: [snapshot]))

        #expect(result.baselineAfter.identityRecords.count == 1)
        #expect(result.baselineAfter.identityRecords[0].logicalNodeID == durableID)
        #expect(result.baselineAfter.revision == BaselineRevision(2))
        #expect(result.reconciliationReport.reusedIdentities.count == 1)
    }

    @Test("A new matching source joins an identity already known by the Baseline")
    func newSourceJoinsExistingIdentity() async throws {
        let knownSource = PipelineTestSupport.sourceID(1)
        let newSource = PipelineTestSupport.sourceID(2)
        let provisionalID = PipelineTestSupport.logicalID(1)
        let durableID = PipelineTestSupport.logicalID(100)
        let baseline = try PipelineTestSupport.baseline(records: [
            PipelineTestSupport.record(
                logicalID: durableID,
                observations: [PipelineTestSupport.observation(
                    sourceID: knownSource,
                    provisionalID: provisionalID,
                    first: PipelineTestSupport.date(10),
                    last: PipelineTestSupport.date(10)
                )]
            ),
        ])
        let snapshots = try [knownSource, newSource].map {
            try PipelineTestSupport.snapshot(
                sourceID: $0,
                nodeID: provisionalID
            )
        }
        let provider = PipelineTestIdentityProvider(ids: [])

        let result = try await PipelineTestSupport.pipeline(
            repository: PipelineTestRepository(baseline: baseline),
            provider: provider
        ).execute(request: MatchingPipelineRequest(snapshots: snapshots))

        #expect(result.baselineAfter.identityRecords.count == 1)
        #expect(result.baselineAfter.identityRecords[0].logicalNodeID == durableID)
        #expect(result.baselineAfter.identityRecords[0].observations.count == 2)
        #expect(result.logicalSnapshots.allSatisfy {
            $0.tree.nodes.first?.logicalID == durableID
        })
        #expect(provider.callCount == 0)
    }

    @Test("Matching Engine groups the same occurrence across multiple snapshots")
    func multipleSnapshots() async throws {
        let provisionalID = PipelineTestSupport.logicalID(1)
        let durableID = PipelineTestSupport.logicalID(100)
        let snapshots = try [1, 2].map {
            try PipelineTestSupport.snapshot(
                sourceID: PipelineTestSupport.sourceID($0),
                nodeID: provisionalID
            )
        }
        let repository = PipelineTestRepository(
            baseline: try PipelineTestSupport.emptyBaseline()
        )

        let result = try await PipelineTestSupport.pipeline(
            repository: repository,
            provider: PipelineTestIdentityProvider(ids: [durableID])
        ).execute(request: MatchingPipelineRequest(snapshots: Array(snapshots.reversed())))

        #expect(result.logicalSnapshots.count == 2)
        #expect(result.baselineAfter.identityRecords.count == 1)
        #expect(result.baselineAfter.identityRecords[0].observations.count == 2)
        #expect(result.pipelineReport.matchingGroupCount == 1)
        #expect(result.pipelineReport.matchedGroupCount == 1)
    }

    @Test("Homologous permanent roots share one durable identity from an empty Baseline")
    func permanentRootsFromEmptyBaselineAreStable() async throws {
        let durableID = PipelineTestSupport.logicalID(100)
        let repository = PipelineTestRepository(
            baseline: try PipelineTestSupport.emptyBaseline()
        )
        let provider = PipelineTestIdentityProvider(ids: [durableID])
        let snapshots = try [
            PipelineTestSupport.snapshot(
                sourceID: PipelineTestSupport.sourceID(1),
                nodeID: PipelineTestSupport.logicalID(1),
                permanentRootRole: .primaryBookmarks
            ),
            PipelineTestSupport.snapshot(
                sourceID: PipelineTestSupport.sourceID(2),
                nodeID: PipelineTestSupport.logicalID(2),
                permanentRootRole: .primaryBookmarks
            ),
        ]
        let pipeline = PipelineTestSupport.pipeline(
            repository: repository,
            provider: provider
        )

        let first = try await pipeline.execute(
            request: MatchingPipelineRequest(snapshots: snapshots)
        )
        let second = try await pipeline.execute(
            request: MatchingPipelineRequest(snapshots: snapshots)
        )
        let third = try await pipeline.execute(
            request: MatchingPipelineRequest(snapshots: snapshots)
        )

        #expect(first.baselineAfter.identityRecords.count == 1)
        #expect(first.baselineAfter.identityRecords[0].observations.count == 2)
        #expect(first.logicalSnapshots.allSatisfy {
            $0.tree.nodes.first?.logicalID == durableID
                && $0.tree.nodes.first?.permanentRootRole == .primaryBookmarks
        })
        #expect(second.baselineAfter == first.baselineAfter)
        #expect(third.baselineAfter == first.baselineAfter)
        #expect(provider.callCount == 1)
    }

    @Test("Non-homologous permanent roots remain distinct")
    func nonHomologousPermanentRootsRemainDistinct() async throws {
        let firstDurableID = PipelineTestSupport.logicalID(100)
        let secondDurableID = PipelineTestSupport.logicalID(101)
        let snapshots = try [
            PipelineTestSupport.snapshot(
                sourceID: PipelineTestSupport.sourceID(1),
                nodeID: PipelineTestSupport.logicalID(1),
                permanentRootRole: .readingList
            ),
            PipelineTestSupport.snapshot(
                sourceID: PipelineTestSupport.sourceID(2),
                nodeID: PipelineTestSupport.logicalID(2),
                permanentRootRole: .mobileBookmarks
            ),
        ]

        let result = try await PipelineTestSupport.pipeline(
            repository: PipelineTestRepository(
                baseline: try PipelineTestSupport.emptyBaseline()
            ),
            provider: PipelineTestIdentityProvider(
                ids: [firstDurableID, secondDurableID]
            )
        ).execute(request: MatchingPipelineRequest(snapshots: snapshots))

        #expect(result.baselineAfter.identityRecords.count == 2)
        #expect(Set(result.logicalSnapshots.compactMap {
            $0.tree.nodes.first?.logicalID
        }).count == 2)
    }

    @Test("A Matching Engine failure stops before reconciliation and transaction")
    func matchingFailure() async throws {
        let repository = PipelineTestRepository(
            baseline: try PipelineTestSupport.emptyBaseline()
        )
        let pipeline = MatchingPipeline(
            baselineRepository: repository,
            matchingEngine: FailingPipelineMatcher(),
            groupBuilder: DefaultIdentityMatchingGroupBuilder(),
            reconciliationEngine: FailingReconciliationEngine(
                shouldFail: false,
                fallback: try PipelineTestSupport.emptyReconciliationResult()
            )
        )
        let snapshots = try [1, 2].map {
            try PipelineTestSupport.snapshot(
                sourceID: PipelineTestSupport.sourceID($0),
                nodeID: PipelineTestSupport.logicalID($0)
            )
        }

        await #expect(throws: MatchingPipelineError.self) {
            _ = try await pipeline.execute(
                request: MatchingPipelineRequest(snapshots: snapshots)
            )
        }
        #expect(await repository.applyCount == 0)
    }

    @Test("A reconciliation failure stops before the Baseline transaction")
    func reconciliationFailure() async throws {
        let repository = PipelineTestRepository(
            baseline: try PipelineTestSupport.emptyBaseline()
        )
        let pipeline = MatchingPipeline(
            baselineRepository: repository,
            matchingEngine: MatchingEngine(),
            groupBuilder: DefaultIdentityMatchingGroupBuilder(),
            reconciliationEngine: FailingReconciliationEngine(
                shouldFail: true,
                fallback: try PipelineTestSupport.emptyReconciliationResult()
            )
        )

        await #expect(throws: MatchingPipelineError.self) {
            _ = try await pipeline.execute(
                request: MatchingPipelineRequest(snapshots: [])
            )
        }
        #expect(await repository.applyCount == 0)
    }

    @Test("A failed Baseline transaction leaves the stored Baseline intact")
    func baselineTransactionFailure() async throws {
        let baseline = try PipelineTestSupport.emptyBaseline()
        let repository = PipelineTestRepository(
            baseline: baseline,
            failure: .transaction
        )
        let snapshot = try PipelineTestSupport.snapshot(
            sourceID: PipelineTestSupport.sourceID(1),
            nodeID: PipelineTestSupport.logicalID(1)
        )

        await #expect(throws: MatchingPipelineError.self) {
            _ = try await PipelineTestSupport.pipeline(
                repository: repository,
                provider: PipelineTestIdentityProvider(
                    ids: [PipelineTestSupport.logicalID(100)]
                )
            ).execute(request: MatchingPipelineRequest(snapshots: [snapshot]))
        }
        #expect(await repository.storedBaseline == baseline)
        #expect(await repository.applyCount == 1)
    }

    @Test("A transaction revision conflict retains its typed revisions")
    func revisionConflict() async throws {
        let baseline = try PipelineTestSupport.emptyBaseline()
        let repository = PipelineTestRepository(
            baseline: baseline,
            failure: .revisionConflict(actual: BaselineRevision(1))
        )

        do {
            _ = try await PipelineTestSupport.pipeline(
                repository: repository,
                provider: PipelineTestIdentityProvider(ids: [])
            ).execute(request: MatchingPipelineRequest(snapshots: []))
            Issue.record("Expected revision conflict")
        } catch let MatchingPipelineError.baselineRevisionConflict(expected, actual) {
            #expect(expected == .zero)
            #expect(actual == BaselineRevision(1))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(await repository.storedBaseline == baseline)
    }

    @Test("Duplicate snapshot sources fail before Matching Engine")
    func duplicateSnapshotSource() async throws {
        let sourceID = PipelineTestSupport.sourceID(1)
        let repository = PipelineTestRepository(
            baseline: try PipelineTestSupport.emptyBaseline()
        )
        let snapshots = try [1, 2].map {
            try PipelineTestSupport.snapshot(
                sourceID: sourceID,
                nodeID: PipelineTestSupport.logicalID($0)
            )
        }

        do {
            _ = try await PipelineTestSupport.pipeline(
                repository: repository,
                provider: PipelineTestIdentityProvider(ids: [])
            ).execute(request: MatchingPipelineRequest(snapshots: snapshots))
            Issue.record("Expected duplicate source rejection")
        } catch let MatchingPipelineError.duplicateSnapshotSource(actual) {
            #expect(actual == sourceID)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(await repository.applyCount == 0)
    }

    @Test("Identical inputs and dependencies produce identical results")
    func deterministic() async throws {
        let baseline = try PipelineTestSupport.emptyBaseline()
        let snapshot = try PipelineTestSupport.snapshot(
            sourceID: PipelineTestSupport.sourceID(1),
            nodeID: PipelineTestSupport.logicalID(1)
        )
        let durableID = PipelineTestSupport.logicalID(100)

        let first = try await PipelineTestSupport.pipeline(
            repository: PipelineTestRepository(baseline: baseline),
            provider: PipelineTestIdentityProvider(ids: [durableID])
        ).execute(request: MatchingPipelineRequest(snapshots: [snapshot]))
        let second = try await PipelineTestSupport.pipeline(
            repository: PipelineTestRepository(baseline: baseline),
            provider: PipelineTestIdentityProvider(ids: [durableID])
        ).execute(request: MatchingPipelineRequest(snapshots: [snapshot]))

        #expect(first == second)
    }

    @Test("Pipeline boundaries and result models are Sendable")
    func strictConcurrency() throws {
        let repository = PipelineTestRepository(
            baseline: try PipelineTestSupport.emptyBaseline()
        )
        let pipeline = PipelineTestSupport.pipeline(
            repository: repository,
            provider: PipelineTestIdentityProvider(ids: [])
        )

        requireSendable(pipeline)
        requireSendable(MatchingPipelineRequest(snapshots: []))
        requireSendable(DefaultIdentityMatchingGroupBuilder())
        requireSendable(MatchingEngine())
    }

    private func requireSendable<T: Sendable>(_ value: T) { _ = value }
}

private enum PipelineTestFailure: Error, Sendable {
    case matching
    case reconciliation
    case transaction
}

private struct FailingPipelineMatcher: MatchingPipelineMatching {
    func match(_ node: BSENode, among candidates: [BSENode]) throws -> MatchingResult {
        throw PipelineTestFailure.matching
    }
}

private struct FailingReconciliationEngine: IdentityReconciliationProcessing {
    let shouldFail: Bool
    let fallback: IdentityReconciliationResult

    func reconcile(
        request: IdentityReconciliationRequest
    ) throws -> IdentityReconciliationResult {
        if shouldFail { throw PipelineTestFailure.reconciliation }
        return fallback
    }
}

private actor PipelineTestRepository: MatchingPipelineBaselineRepository {
    enum Failure: Sendable {
        case none
        case transaction
        case revisionConflict(actual: BaselineRevision)
    }

    private var baseline: Baseline?
    private let failure: Failure
    private(set) var applyCount = 0

    init(baseline: Baseline?, failure: Failure = .none) {
        self.baseline = baseline
        self.failure = failure
    }

    var storedBaseline: Baseline? { baseline }

    func load() async throws -> Baseline? { baseline }

    func apply(
        commands: [BaselineCommand],
        expectedRevision: BaselineRevision
    ) async throws -> BaselineChangeSet {
        applyCount += 1
        guard let baseline else { throw BaselineError.baselineNotFound }
        switch failure {
        case .none:
            guard baseline.revision == expectedRevision else {
                throw BaselineError.revisionConflict(
                    expected: expectedRevision,
                    actual: baseline.revision
                )
            }
            let changeSet = try BaselineEngine().apply(
                commands: commands,
                to: baseline
            )
            self.baseline = changeSet.baseline
            return changeSet
        case .transaction:
            throw PipelineTestFailure.transaction
        case .revisionConflict(let actual):
            throw BaselineError.revisionConflict(
                expected: expectedRevision,
                actual: actual
            )
        }
    }
}

private final class PipelineTestIdentityProvider: IdentityProvider, @unchecked Sendable {
    enum Failure: Error { case exhausted }

    private let lock = NSLock()
    private var ids: [LogicalNodeID]
    private var storedCallCount = 0

    init(ids: [LogicalNodeID]) { self.ids = ids }

    func nextLogicalNodeID() throws -> LogicalNodeID {
        lock.lock()
        defer { lock.unlock() }
        storedCallCount += 1
        guard !ids.isEmpty else { throw Failure.exhausted }
        return ids.removeFirst()
    }

    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedCallCount
    }
}

private enum PipelineTestSupport {
    static func pipeline(
        repository: PipelineTestRepository,
        provider: PipelineTestIdentityProvider
    ) -> MatchingPipeline {
        MatchingPipeline(
            baselineRepository: repository,
            matchingEngine: MatchingEngine(),
            groupBuilder: DefaultIdentityMatchingGroupBuilder(),
            reconciliationEngine: IdentityReconciliationEngine(
                identityProvider: provider,
                matchingPolicy: StrictIdentityMatchingPolicy(),
                snapshotBuilder: LogicalSnapshotBuilder()
            )
        )
    }

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
        observations: [BaselineObservation]
    ) throws -> IdentityRecord {
        try IdentityRecord(
            logicalNodeID: logicalID,
            revision: IdentityRevision(1),
            state: .active,
            observations: observations,
            metadata: IdentityRecordMetadata(
                createdInBaselineRevision: BaselineRevision(1),
                lastChangedInBaselineRevision: BaselineRevision(1)
            )
        )
    }

    static func observation(
        sourceID: BSESourceID,
        provisionalID: LogicalNodeID,
        first: Date,
        last: Date
    ) throws -> BaselineObservation {
        try BaselineObservation(
            sourceID: sourceID,
            provisionalLogicalID: provisionalID,
            recognitionArtifacts: [],
            firstObservedAt: first,
            lastObservedAt: last,
            presence: .present
        )
    }

    static func snapshot(
        sourceID: BSESourceID,
        capturedAt: Date = date(20),
        nodeID: LogicalNodeID,
        permanentRootRole: PermanentRootRole? = nil
    ) throws -> BSESnapshot {
        BSESnapshot(
            source: sourceID,
            capturedAt: capturedAt,
            tree: try BSETree(nodes: [BSENode(
                logicalID: nodeID,
                kind: .folder,
                permanentRootRole: permanentRootRole,
                title: "Folder",
                position: 0
            )])
        )
    }

    static func emptyReconciliationResult() throws -> IdentityReconciliationResult {
        IdentityReconciliationResult(
            logicalSnapshots: [],
            baselineCommands: [],
            report: IdentityReconciliationReport(
                createdIdentities: [],
                reusedIdentities: [],
                ambiguities: [],
                unresolvedObjects: [],
                diagnostics: [],
                statistics: IdentityReconciliationStatistics(
                    snapshotCount: 0,
                    logicalSnapshotCount: 0,
                    groupCount: 0,
                    createdIdentityCount: 0,
                    reusedIdentityCount: 0,
                    ambiguityCount: 0,
                    unresolvedObjectCount: 0,
                    baselineCommandCount: 0
                )
            )
        )
    }

    static func sourceID(_ value: Int) -> BSESourceID {
        BSESourceID(uuid(value))
    }

    static func logicalID(_ value: Int) -> LogicalNodeID {
        LogicalNodeID(uuid(value))
    }

    static func date(_ value: TimeInterval) -> Date {
        Date(timeIntervalSince1970: value)
    }

    private static func uuid(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}
