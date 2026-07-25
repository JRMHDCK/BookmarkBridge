//
//  SynchronizationPipelineTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("BSE-794 Shared Synchronization Pipeline")
struct SynchronizationPipelineTests {
    @Test("The shared read-only composition is deterministic")
    func deterministicComposition() async throws {
        let sourceID = pipelineSourceID(1)
        let targetID = pipelineSourceID(2)
        let root = try pipelineFolder(1, "Root")
        let created = try pipelineBookmark(
            2,
            "Created",
            parent: 1
        )
        let source = BSESnapshot(
            source: sourceID,
            capturedAt: Date(timeIntervalSince1970: 1),
            tree: try BSETree(nodes: [root, created])
        )
        let target = BSESnapshot(
            source: targetID,
            capturedAt: Date(timeIntervalSince1970: 1),
            tree: try BSETree(nodes: [root])
        )
        let pipeline = SynchronizationPipeline(
            matchingPipeline: PipelineMatchingProcessor(),
            identityResolver: PipelinePassthroughIdentityResolver(),
            bootstrapper: PipelineBootstrapper()
        )
        let request = SynchronizationPipelineRequest(
            sourceReader: PipelineReader(snapshot: source),
            targetReader: PipelineReader(snapshot: target),
            policy: .allChanges(direction: .oneWay(
                source: sourceID,
                target: targetID
            ))
        )

        let first = try await pipeline.execute(request: request)
        let second = try await pipeline.execute(request: request)

        #expect(first == second)
        #expect(first.sourceRead.snapshot == source)
        #expect(first.targetRead.snapshot == target)
        #expect(
            first.reconciliationReport
                == first.matching.reconciliationReport
        )
        #expect(first.logicalDiff.changes.count == 1)
        #expect(first.plan.phases.flatMap(\.operations).count == 1)
        guard case .create(let operation)? =
            first.plan.phases.flatMap(\.operations).first else {
            Issue.record("Expected the unchanged shared planner to create once")
            return
        }
        #expect(operation.logicalNodeID == created.logicalID)
    }

    @Test("Analysis stops before planning and remains usable for verification")
    func analysisStopsBeforePlanning() async throws {
        let sourceID = pipelineSourceID(1)
        let targetID = pipelineSourceID(2)
        let root = try pipelineFolder(1, "Root")
        let snapshot = BSESnapshot(
            source: sourceID,
            capturedAt: Date(timeIntervalSince1970: 1),
            tree: try BSETree(nodes: [root])
        )
        let targetSnapshot = BSESnapshot(
            source: targetID,
            capturedAt: snapshot.capturedAt,
            tree: snapshot.tree
        )
        let pipeline = SynchronizationPipeline(
            matchingPipeline: PipelineMatchingProcessor(),
            identityResolver: PipelinePassthroughIdentityResolver(),
            bootstrapper: PipelineBootstrapper(),
            planner: FailingPipelinePlanner()
        )
        let request = SynchronizationPipelineRequest(
            sourceReader: PipelineReader(snapshot: snapshot),
            targetReader: PipelineReader(snapshot: targetSnapshot),
            policy: .allChanges(direction: .oneWay(
                source: sourceID,
                target: targetID
            ))
        )

        let analysis = try await pipeline.analyze(request: request)

        #expect(analysis.logicalDiff.changes.isEmpty)
        await #expect(throws: SynchronizationPipelineError.self) {
            _ = try await pipeline.execute(request: request)
        }
    }

    @Test("Native identities are resolved before Matching")
    func resolvesBeforeMatching() async throws {
        let sourceID = pipelineSourceID(1)
        let targetID = pipelineSourceID(2)
        let provisionalID = pipelineLogicalID(1)
        let durableID = pipelineLogicalID(101)
        let nativeID = NativeNodeIdentifier("native-root")
        let source = BSESnapshot(
            source: sourceID,
            capturedAt: Date(timeIntervalSince1970: 1),
            tree: try BSETree(nodes: [pipelineFolder(1, "Root")])
        )
        let target = BSESnapshot(
            source: targetID,
            capturedAt: source.capturedAt,
            tree: source.tree
        )
        let repository = InMemoryNativeIdentityRepository(mappings: [
            NativeIdentityMapping(
                logicalNodeID: durableID,
                sourceID: sourceID,
                nativeIdentifier: nativeID
            ),
        ])
        let pipeline = SynchronizationPipeline(
            matchingPipeline: ResolutionCheckingMatchingProcessor(
                expectedSourceLogicalID: durableID
            ),
            identityResolver: NativeIdentityResolver(repository: repository),
            bootstrapper: PipelineBootstrapper()
        )
        let request = SynchronizationPipelineRequest(
            sourceReader: PipelineReader(
                snapshot: source,
                nativeIdentityObservations: [
                    NativeIdentityObservation(
                        sourceID: sourceID,
                        provisionalLogicalNodeID: provisionalID,
                        nativeIdentifier: nativeID
                    ),
                ]
            ),
            targetReader: PipelineReader(
                snapshot: target,
                nativeIdentityObservations: [
                    NativeIdentityObservation(
                        sourceID: targetID,
                        provisionalLogicalNodeID: provisionalID,
                        nativeIdentifier: NativeNodeIdentifier("target-root")
                    ),
                ]
            ),
            policy: .allChanges(direction: .oneWay(
                source: sourceID,
                target: targetID
            ))
        )

        let analysis = try await pipeline.analyze(request: request)

        #expect(analysis.sourceRead == EndToEndSynchronizationReadResult(
            snapshot: source,
            nativeIdentityObservations: [
                NativeIdentityObservation(
                    sourceID: sourceID,
                    provisionalLogicalNodeID: provisionalID,
                    nativeIdentifier: nativeID
                ),
            ]
        ))
        #expect(
            repository.logicalNodeID(
                for: nativeID,
                sourceID: sourceID
            ) == durableID
        )
    }

    @Test("Pipeline request, result, and composition are Sendable")
    func strictConcurrency() async throws {
        let sourceID = pipelineSourceID(1)
        let targetID = pipelineSourceID(2)
        let root = try pipelineFolder(1, "Root")
        let source = BSESnapshot(
            source: sourceID,
            capturedAt: Date(timeIntervalSince1970: 1),
            tree: try BSETree(nodes: [root])
        )
        let target = BSESnapshot(
            source: targetID,
            capturedAt: source.capturedAt,
            tree: source.tree
        )
        let pipeline = SynchronizationPipeline(
            matchingPipeline: PipelineMatchingProcessor(),
            identityResolver: PipelinePassthroughIdentityResolver(),
            bootstrapper: PipelineBootstrapper()
        )
        let request = SynchronizationPipelineRequest(
            sourceReader: PipelineReader(snapshot: source),
            targetReader: PipelineReader(snapshot: target),
            policy: .allChanges(direction: .oneWay(
                source: sourceID,
                target: targetID
            ))
        )

        let result = try await Task.detached {
            try await pipeline.execute(request: request)
        }.value

        #expect(result.logicalDiff.changes.isEmpty)
    }
}

private struct PipelineReader: EndToEndSynchronizationReading {
    let snapshot: BSESnapshot
    let nativeIdentityObservations: [NativeIdentityObservation]

    init(
        snapshot: BSESnapshot,
        nativeIdentityObservations: [NativeIdentityObservation] = []
    ) {
        self.snapshot = snapshot
        self.nativeIdentityObservations = nativeIdentityObservations
    }

    var sourceID: BSESourceID {
        snapshot.source
    }

    func readForSynchronization() async throws
        -> EndToEndSynchronizationReadResult {
        EndToEndSynchronizationReadResult(
            snapshot: snapshot,
            nativeIdentityObservations: nativeIdentityObservations
        )
    }
}

private struct ResolutionCheckingMatchingProcessor:
    SynchronizationMatchingProcessing
{
    let expectedSourceLogicalID: LogicalNodeID

    func execute(
        request: MatchingPipelineRequest
    ) async throws -> MatchingPipelineResult {
        guard request.snapshots.first?.tree.nodes.first?.logicalID
                == expectedSourceLogicalID else {
            throw PipelineTestError.identityResolutionDidNotRun
        }
        return try await PipelineMatchingProcessor().execute(request: request)
    }
}

private struct PipelineMatchingProcessor: SynchronizationMatchingProcessing {
    func execute(
        request: MatchingPipelineRequest
    ) async throws -> MatchingPipelineResult {
        let baseline = try Baseline.empty(
            baselineID: BaselineID(UUID(
                uuidString: "FA000000-0000-0000-0000-000000000001"
            )!)
        )
        let logicalSnapshots = request.snapshots.map {
            LogicalSnapshot(
                source: $0.source,
                capturedAt: $0.capturedAt,
                tree: $0.tree
            )
        }
        let report = IdentityReconciliationReport(
            createdIdentities: [],
            reusedIdentities: [],
            ambiguities: [],
            unresolvedObjects: [],
            diagnostics: [],
            statistics: IdentityReconciliationStatistics(
                snapshotCount: request.snapshots.count,
                logicalSnapshotCount: logicalSnapshots.count,
                groupCount: 0,
                createdIdentityCount: 0,
                reusedIdentityCount: 0,
                ambiguityCount: 0,
                unresolvedObjectCount: 0,
                baselineCommandCount: 0
            )
        )
        return MatchingPipelineResult(
            baselineBefore: baseline,
            baselineAfter: baseline,
            logicalSnapshots: logicalSnapshots,
            reconciliationReport: report,
            pipelineReport: MatchingPipelineReport(
                snapshotCount: request.snapshots.count,
                nodeCount: request.snapshots.reduce(0) {
                    $0 + $1.tree.count
                },
                matchingGroupCount: 0,
                matchedGroupCount: 0,
                unmatchedGroupCount: 0,
                ambiguousGroupCount: 0,
                baselineMutationCount: 0,
                baselineTransactionPersisted: false,
                baselineRevisionBefore: .zero,
                baselineRevisionAfter: .zero
            )
        )
    }
}

private struct PipelineBootstrapper:
    SynchronizationNativeIdentityBootstrapping
{
    func bootstrap(
        reconciliationReport: IdentityReconciliationReport,
        observations: [NativeIdentityObservation]
    ) throws -> NativeIdentityBootstrapResult {
        NativeIdentityBootstrapResult(
            observationsProcessed: observations.count,
            mappingsCreated: 0,
            mappingsAlreadyPresent: 0,
            conflictsDetected: 0
        )
    }
}

private struct PipelinePassthroughIdentityResolver:
    SynchronizationNativeIdentityResolving
{
    func resolve(
        _ readResult: EndToEndSynchronizationReadResult
    ) -> NativeIdentityResolutionResult {
        NativeIdentityResolutionResult(
            readResult: readResult,
            resolvedIdentityCount: 0,
            unresolvedIdentityCount: readResult.snapshot.tree.count
        )
    }
}

private struct FailingPipelinePlanner: SynchronizationPlanning {
    func plan(
        request: SynchronizationPlanningRequest
    ) throws -> SynchronizationPlan {
        throw PipelineTestError.planningMustNotRun
    }
}

private enum PipelineTestError: Error {
    case planningMustNotRun
    case identityResolutionDidNotRun
}

private func pipelineFolder(
    _ id: Int,
    _ title: String,
    parent: Int? = nil
) throws -> BSENode {
    try BSENode(
        logicalID: pipelineLogicalID(id),
        kind: .folder,
        title: title,
        parentID: parent.map(pipelineLogicalID),
        position: 0
    )
}

private func pipelineBookmark(
    _ id: Int,
    _ title: String,
    parent: Int
) throws -> BSENode {
    try BSENode(
        logicalID: pipelineLogicalID(id),
        kind: .bookmark,
        title: title,
        parentID: pipelineLogicalID(parent),
        position: 0,
        url: URL(string: "https://example.test")
    )
}

private func pipelineLogicalID(_ value: Int) -> LogicalNodeID {
    LogicalNodeID(UUID(uuidString: String(
        format: "FA100000-0000-0000-0000-%012d",
        value
    ))!)
}

private func pipelineSourceID(_ value: Int) -> BSESourceID {
    BSESourceID(UUID(uuidString: String(
        format: "FA200000-0000-0000-0000-%012d",
        value
    ))!)
}
