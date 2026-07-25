//
//  EndToEndSynchronizationPipelineTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Synchronization
import Testing
@testable import BookmarkBridge

@Suite("BSE End-to-End Synchronization")
struct EndToEndSynchronizationPipelineTests {
    @Test("An already synchronized target produces no operation but is reread")
    func noModification() async throws {
        let root = try folder(1, "Root")
        let scenario = try Scenario(
            sourceNodes: [root],
            targetBeforeNodes: [root],
            expectedTargetNodes: [root]
        )

        let outcome = try await run(scenario)

        #expect(outcome.result.plan.operations.isEmpty)
        #expect(outcome.result.execution.report.attemptedOperationCount == 0)
        #expect(outcome.result.diffAfter.changes.isEmpty)
        #expect(outcome.world.sourceReadCount == 1)
        #expect(outcome.world.targetReadCount == 2)
        #expect(outcome.world.writeCount == 0)
    }

    @Test(
        "Each logical change is written once and disappears after rereading",
        arguments: EndToEndChangeScenario.all
    )
    func individualChanges(change: EndToEndChangeScenario) async throws {
        let scenario = try change.scenario()

        let outcome = try await run(scenario)

        #expect(outcome.result.plan.operations.map(\.writeOperationKind)
            == change.expectedOperationKinds)
        #expect(outcome.result.diffAfter.changes.isEmpty)
        #expect(outcome.world.targetReadCount == 2)
        #expect(outcome.world.writeCount == change.expectedOperationKinds.count)
    }

    @Test("A complete synchronization executes once then verifies an empty diff")
    func completeSynchronization() async throws {
        let source = try [
            folder(1, "Root"),
            folder(2, "Destination", parent: 1),
            bookmark(
                3,
                "Renamed",
                parent: 2,
                url: "https://after.test"
            ),
            bookmark(4, "Created", parent: 1, position: 1),
        ]
        let target = try [
            folder(1, "Root"),
            folder(2, "Destination", parent: 1),
            bookmark(
                3,
                "Before",
                parent: 1,
                url: "https://before.test"
            ),
            bookmark(5, "Deleted", parent: 1, position: 1),
        ]
        let scenario = try Scenario(
            sourceNodes: source,
            targetBeforeNodes: target,
            expectedTargetNodes: source
        )

        let outcome = try await run(scenario)

        #expect(!outcome.result.diffBefore.changes.isEmpty)
        #expect(outcome.result.diffAfter.changes.isEmpty)
        #expect(outcome.result.execution.status == .completed)
        #expect(outcome.world.targetReadCount == 2)
        #expect(outcome.trace.events.filter { $0 == "execute" }.count == 1)
        #expect(outcome.trace.events.filter { $0 == "matching" }.count == 2)
        #expect(outcome.trace.events.filter { $0 == "bootstrap" }.count == 2)
        #expect(outcome.trace.events.filter { $0 == "projection" }.count == 2)
        #expect(outcome.trace.events.filter { $0 == "diff" }.count == 2)
        #expect(outcome.trace.events.filter { $0 == "plan" }.count == 1)
        let executeIndex = try #require(
            outcome.trace.events.firstIndex(of: "execute")
        )
        let secondTargetReadIndex = try #require(
            outcome.trace.events.lastIndex(of: "targetRead")
        )
        #expect(executeIndex < secondTargetReadIndex)
    }

    @Test("End-to-end execution preserves dependency-ordered nested creations")
    func dependencyOrderedNestedCreation() async throws {
        let root = try folder(100, "Root")
        let parent = try folder(90, "Parent", parent: 100)
        let child = try folder(80, "Child", parent: 90)
        let grandchild = try folder(70, "Grandchild", parent: 80)
        let terminal = try bookmark(60, "Terminal", parent: 70)
        let source = [root, parent, child, grandchild, terminal]
        let scenario = try Scenario(
            sourceNodes: source,
            targetBeforeNodes: [root],
            expectedTargetNodes: source
        )

        let outcome = try await run(scenario)

        #expect(outcome.result.plan.phases[0].operations.map(\.logicalNodeID) == [
            parent.logicalID,
            child.logicalID,
            grandchild.logicalID,
            terminal.logicalID,
        ])
        #expect(outcome.result.execution.status == .completed)
        #expect(outcome.world.writeCount == 4)
        #expect(outcome.result.diffAfter.changes.isEmpty)
    }

    @Test("End-to-end execution moves before a position-dependent creation")
    func positionDependentMoveThenCreate() async throws {
        let root = try folder(1, "Root")
        let destination = try folder(2, "Destination", parent: 1)
        let origin = try folder(3, "Origin", parent: 1, position: 1)
        let movedBefore = try bookmark(4, "Moved", parent: 3)
        let movedAfter = try bookmark(4, "Moved", parent: 2)
        let created = try bookmark(
            5,
            "Created",
            parent: 2,
            position: 1
        )
        let scenario = try Scenario(
            sourceNodes: [
                root,
                destination,
                origin,
                movedAfter,
                created,
            ],
            targetBeforeNodes: [
                root,
                destination,
                origin,
                movedBefore,
            ],
            expectedTargetNodes: [
                root,
                destination,
                origin,
                movedAfter,
                created,
            ]
        )

        let outcome = try await run(scenario)

        #expect(outcome.result.plan.phases[0].operations.isEmpty)
        #expect(outcome.result.plan.phases[1].operations.map(\.logicalNodeID) == [
            movedBefore.logicalID,
            created.logicalID,
        ])
        #expect(outcome.result.execution.status == .completed)
        #expect(outcome.world.writeCount == 2)
        #expect(outcome.result.diffAfter.changes.isEmpty)
    }

    @Test("A residual diff fails explicitly without a second execution")
    func residualDiff() async throws {
        let source = try [
            folder(1, "Root"),
            bookmark(2, "Created", parent: 1),
        ]
        let target = try [folder(1, "Root")]
        let scenario = try Scenario(
            sourceNodes: source,
            targetBeforeNodes: target,
            expectedTargetNodes: target,
            adapterUpdatesTarget: false
        )
        let environment = makeEnvironment(scenario)

        do {
            _ = try await environment.pipeline.execute(
                request: environment.request
            )
            Issue.record("A residual diff must fail verification")
        } catch let error as EndToEndSynchronizationError {
            guard case .residualDiff(let changes) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(!changes.isEmpty)
        }

        #expect(environment.trace.events.filter { $0 == "execute" }.count == 1)
        #expect(environment.world.writeCount == 1)
        #expect(environment.world.targetReadCount == 2)
    }

    @Test("A failed execution stops before the verification reread")
    func executionFailure() async throws {
        let source = try [
            folder(1, "Root"),
            bookmark(2, "Created", parent: 1),
        ]
        let scenario = try Scenario(
            sourceNodes: source,
            targetBeforeNodes: [folder(1, "Root")],
            expectedTargetNodes: source,
            adapterFails: true
        )
        let environment = makeEnvironment(scenario)

        await #expect(throws: EndToEndSynchronizationError.executionFailed(
            .stoppedOnFailure
        )) {
            try await environment.pipeline.execute(request: environment.request)
        }

        #expect(environment.world.targetReadCount == 1)
    }

    @Test(
        "Each pre-execution pipeline failure keeps its public category",
        arguments: EndToEndPipelineFailureScenario.allCases
    )
    private func mapsPreExecutionPipelineFailure(
        _ failure: EndToEndPipelineFailureScenario
    ) async throws {
        let root = try folder(1, "Root")
        let scenario = try Scenario(
            sourceNodes: [root],
            targetBeforeNodes: [root],
            expectedTargetNodes: [root]
        )
        let trace = TestTrace()
        let world = TestWorld(scenario: scenario, trace: trace)
        let pipelineDouble = FailingEndToEndPipelineDouble(
            error: failure.pipelineError
        )
        let executor = CountingEndToEndExecutor()
        let pipeline = EndToEndSynchronizationPipeline(
            sourceReader: TestReader(
                sourceID: sourceID,
                role: .source,
                world: world
            ),
            targetReader: TestReader(
                sourceID: targetID,
                role: .target,
                world: world
            ),
            synchronizationPipeline: pipelineDouble,
            executor: executor,
            writeAdapter: TestWriteAdapter(
                sourceID: targetID,
                world: world
            )
        )
        let request = EndToEndSynchronizationRequest(
            synchronizationPolicy: .allChanges(direction: .oneWay(
                source: sourceID,
                target: targetID
            )),
            writeContext: WriteExecutionContext(
                sourceID: targetID,
                mode: .apply
            ),
            executionPolicy: .stopOnFirstFailure
        )

        let error = await capturedEndToEndError {
            try await pipeline.execute(request: request)
        }

        #expect(failure.matches(error))
        #expect(pipelineDouble.executeCount == 1)
        #expect(pipelineDouble.analyzeCount == 0)
        #expect(executor.executeCount == 0)
        #expect(world.sourceReadCount == 0)
        #expect(world.targetReadCount == 0)
    }

    @Test("A verification reread failure keeps its dedicated category")
    func mapsFinalVerificationReadFailure() async throws {
        let root = try folder(1, "Root")
        let scenario = try Scenario(
            sourceNodes: [root],
            targetBeforeNodes: [root],
            expectedTargetNodes: [root]
        )
        let trace = TestTrace()
        let world = TestWorld(scenario: scenario, trace: trace)
        let sourceReader = TestReader(
            sourceID: sourceID,
            role: .source,
            world: world
        )
        let targetReader = TestReader(
            sourceID: targetID,
            role: .target,
            world: world
        )
        let concretePipeline = SynchronizationPipeline(
            matchingPipeline: TestMatchingProcessor(trace: trace),
            identityResolver: EndToEndPassthroughIdentityResolver(),
            bootstrapper: TestBootstrapper(trace: trace),
            projector: TracedProjector(trace: trace),
            diffEngine: TracedDiffEngine(trace: trace),
            planner: TracedPlanner(trace: trace)
        )
        let failureContext = SynchronizationPipelineFailureContext(
            EndToEndPipelineTestFailure.injected
        )
        let pipelineDouble = VerificationFailingPipelineDouble(
            base: concretePipeline,
            error: .targetReadFailure(failureContext)
        )
        let pipeline = EndToEndSynchronizationPipeline(
            sourceReader: sourceReader,
            targetReader: targetReader,
            synchronizationPipeline: pipelineDouble,
            executor: TracedExecutor(trace: trace),
            writeAdapter: TestWriteAdapter(
                sourceID: targetID,
                world: world
            )
        )
        let request = EndToEndSynchronizationRequest(
            synchronizationPolicy: .allChanges(direction: .oneWay(
                source: sourceID,
                target: targetID
            )),
            writeContext: WriteExecutionContext(
                sourceID: targetID,
                mode: .apply
            ),
            executionPolicy: .stopOnFirstFailure
        )

        let error = await capturedEndToEndError {
            try await pipeline.execute(request: request)
        }

        guard case .targetRereadFailure? = error else {
            Issue.record("Expected a target reread failure, got \(String(describing: error))")
            return
        }
        #expect(pipelineDouble.executeCount == 1)
        #expect(pipelineDouble.analyzeCount == 1)
        #expect(trace.events.filter { $0 == "execute" }.count == 1)
    }

    private func run(
        _ scenario: Scenario
    ) async throws -> (
        result: EndToEndSynchronizationResult,
        world: TestWorld,
        trace: TestTrace
    ) {
        let environment = makeEnvironment(scenario)
        let result = try await environment.pipeline.execute(
            request: environment.request
        )
        return (result, environment.world, environment.trace)
    }

    private func makeEnvironment(
        _ scenario: Scenario
    ) -> (
        pipeline: EndToEndSynchronizationPipeline,
        request: EndToEndSynchronizationRequest,
        world: TestWorld,
        trace: TestTrace
    ) {
        let trace = TestTrace()
        let world = TestWorld(scenario: scenario, trace: trace)
        let sourceReader = TestReader(
            sourceID: sourceID,
            role: .source,
            world: world
        )
        let targetReader = TestReader(
            sourceID: targetID,
            role: .target,
            world: world
        )
        let pipeline = EndToEndSynchronizationPipeline(
            sourceReader: sourceReader,
            targetReader: targetReader,
            matchingPipeline: TestMatchingProcessor(trace: trace),
            identityResolver: EndToEndPassthroughIdentityResolver(),
            bootstrapper: TestBootstrapper(trace: trace),
            projector: TracedProjector(trace: trace),
            diffEngine: TracedDiffEngine(trace: trace),
            planner: TracedPlanner(trace: trace),
            executor: TracedExecutor(trace: trace),
            writeAdapter: TestWriteAdapter(
                sourceID: targetID,
                world: world
            )
        )
        let direction = SynchronizationDirection.oneWay(
            source: sourceID,
            target: targetID
        )
        return (
            pipeline,
            EndToEndSynchronizationRequest(
                synchronizationPolicy: .allChanges(direction: direction),
                writeContext: WriteExecutionContext(
                    sourceID: targetID,
                    mode: .apply
                ),
                executionPolicy: .stopOnFirstFailure
            ),
            world,
            trace
        )
    }

    private var sourceID: BSESourceID { makeSourceID(1) }
    private var targetID: BSESourceID { makeSourceID(2) }

    private func folder(
        _ id: Int,
        _ title: String,
        parent: Int? = nil,
        position: Int = 0
    ) throws -> BSENode {
        try BSENode(
            logicalID: makeLogicalID(id),
            kind: .folder,
            title: title,
            parentID: parent.map(makeLogicalID),
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
            logicalID: makeLogicalID(id),
            kind: .bookmark,
            title: title,
            parentID: makeLogicalID(parent),
            position: position,
            url: URL(string: url)
        )
    }
}

private enum EndToEndPipelineFailureScenario:
    String,
    CaseIterable,
    CustomTestStringConvertible,
    Sendable
{
    case sourceRead
    case targetRead
    case matching
    case bootstrap
    case projection
    case diff
    case planning

    var testDescription: String { rawValue }

    var pipelineError: SynchronizationPipelineError {
        let context = SynchronizationPipelineFailureContext(
            EndToEndPipelineTestFailure.injected
        )
        return switch self {
        case .sourceRead: .sourceReadFailure(context)
        case .targetRead: .targetReadFailure(context)
        case .matching: .matchingFailure(context)
        case .bootstrap: .bootstrapFailure(context)
        case .projection: .projectionFailure(context)
        case .diff: .diffFailure(context)
        case .planning: .planningFailure(context)
        }
    }

    func matches(_ error: EndToEndSynchronizationError?) -> Bool {
        switch (self, error) {
        case (.sourceRead, .sourceReadFailure),
            (.targetRead, .targetReadFailure),
            (.matching, .matchingFailure),
            (.bootstrap, .bootstrapFailure),
            (.projection, .projectionFailure),
            (.diff, .diffFailure),
            (.planning, .planningFailure):
            true
        default:
            false
        }
    }
}

private final class FailingEndToEndPipelineDouble:
    SynchronizationPipelineExecuting,
    Sendable
{
    private struct State: Sendable {
        var executeCount = 0
        var analyzeCount = 0
    }

    private let error: SynchronizationPipelineError
    private let state = Mutex(State())

    init(error: SynchronizationPipelineError) {
        self.error = error
    }

    var executeCount: Int {
        state.withLock { $0.executeCount }
    }

    var analyzeCount: Int {
        state.withLock { $0.analyzeCount }
    }

    func execute(
        request: SynchronizationPipelineRequest
    ) async throws -> SynchronizationPipelineResult {
        state.withLock { $0.executeCount += 1 }
        throw error
    }

    func analyze(
        request: SynchronizationPipelineRequest
    ) async throws -> SynchronizationPipelineAnalysis {
        state.withLock { $0.analyzeCount += 1 }
        throw error
    }
}

private final class VerificationFailingPipelineDouble:
    SynchronizationPipelineExecuting,
    Sendable
{
    private struct State: Sendable {
        var executeCount = 0
        var analyzeCount = 0
    }

    private let base: any SynchronizationPipelineExecuting
    private let error: SynchronizationPipelineError
    private let state = Mutex(State())

    init(
        base: any SynchronizationPipelineExecuting,
        error: SynchronizationPipelineError
    ) {
        self.base = base
        self.error = error
    }

    var executeCount: Int {
        state.withLock { $0.executeCount }
    }

    var analyzeCount: Int {
        state.withLock { $0.analyzeCount }
    }

    func execute(
        request: SynchronizationPipelineRequest
    ) async throws -> SynchronizationPipelineResult {
        state.withLock { $0.executeCount += 1 }
        return try await base.execute(request: request)
    }

    func analyze(
        request: SynchronizationPipelineRequest
    ) async throws -> SynchronizationPipelineAnalysis {
        state.withLock { $0.analyzeCount += 1 }
        throw error
    }
}

private final class CountingEndToEndExecutor:
    EndToEndSynchronizationExecuting,
    Sendable
{
    private let count = Mutex(0)

    var executeCount: Int {
        count.withLock { $0 }
    }

    func execute(
        request: SynchronizationExecutionRequest
    ) async -> SynchronizationExecutionResult {
        count.withLock { $0 += 1 }
        return await SynchronizationExecutor().execute(request: request)
    }
}

private enum EndToEndPipelineTestFailure: Error {
    case injected
}

private func capturedEndToEndError(
    _ operation: () async throws -> EndToEndSynchronizationResult
) async -> EndToEndSynchronizationError? {
    do {
        _ = try await operation()
        Issue.record("Expected end-to-end synchronization to fail")
        return nil
    } catch let error as EndToEndSynchronizationError {
        return error
    } catch {
        Issue.record("Unexpected error: \(error)")
        return nil
    }
}

enum EndToEndChangeScenario: String, CaseIterable, CustomTestStringConvertible {
    case creation
    case deletion
    case rename
    case move
    case url

    static let all = Array(allCases)

    var testDescription: String { rawValue }

    var expectedOperationKinds: [WriteOperationKind] {
        switch self {
        case .creation: [.create]
        case .deletion: [.delete]
        case .rename: [.rename]
        case .move: [.move]
        case .url: [.updateURL]
        }
    }

    fileprivate func scenario() throws -> Scenario {
        let root = try testFolder(1, "Root")
        switch self {
        case .creation:
            let source = try [
                root,
                testBookmark(3, "Created", parent: 1),
            ]
            return try Scenario(
                sourceNodes: source,
                targetBeforeNodes: [root],
                expectedTargetNodes: source
            )
        case .deletion:
            let target = try [
                root,
                testBookmark(3, "Deleted", parent: 1),
            ]
            return try Scenario(
                sourceNodes: [root],
                targetBeforeNodes: target,
                expectedTargetNodes: [root]
            )
        case .rename:
            let source = try [
                root,
                testBookmark(3, "After", parent: 1),
            ]
            let target = try [
                root,
                testBookmark(3, "Before", parent: 1),
            ]
            return try Scenario(
                sourceNodes: source,
                targetBeforeNodes: target,
                expectedTargetNodes: source
            )
        case .move:
            let secondParent = try testFolder(
                2,
                "Second",
                parent: 1
            )
            let source = try [
                root,
                secondParent,
                testBookmark(3, "Moved", parent: 2),
            ]
            let target = try [
                root,
                secondParent,
                testBookmark(3, "Moved", parent: 1),
            ]
            return try Scenario(
                sourceNodes: source,
                targetBeforeNodes: target,
                expectedTargetNodes: source
            )
        case .url:
            let source = try [
                root,
                testBookmark(
                    3,
                    "Bookmark",
                    parent: 1,
                    url: "https://after.test"
                ),
            ]
            let target = try [
                root,
                testBookmark(
                    3,
                    "Bookmark",
                    parent: 1,
                    url: "https://before.test"
                ),
            ]
            return try Scenario(
                sourceNodes: source,
                targetBeforeNodes: target,
                expectedTargetNodes: source
            )
        }
    }
}

private struct Scenario: Sendable {
    let source: BSESnapshot
    let targetBefore: BSESnapshot
    let targetAfter: BSESnapshot
    let adapterUpdatesTarget: Bool
    let adapterFails: Bool

    init(
        sourceNodes: [BSENode],
        targetBeforeNodes: [BSENode],
        expectedTargetNodes: [BSENode],
        adapterUpdatesTarget: Bool = true,
        adapterFails: Bool = false
    ) throws {
        source = BSESnapshot(
            source: makeSourceID(1),
            capturedAt: Date(timeIntervalSince1970: 1),
            tree: try BSETree(nodes: sourceNodes)
        )
        targetBefore = BSESnapshot(
            source: makeSourceID(2),
            capturedAt: Date(timeIntervalSince1970: 1),
            tree: try BSETree(nodes: targetBeforeNodes)
        )
        targetAfter = BSESnapshot(
            source: makeSourceID(2),
            capturedAt: Date(timeIntervalSince1970: 2),
            tree: try BSETree(nodes: expectedTargetNodes)
        )
        self.adapterUpdatesTarget = adapterUpdatesTarget
        self.adapterFails = adapterFails
    }
}

private final class TestTrace: Sendable {
    private let storage = Mutex<[String]>([])

    var events: [String] {
        storage.withLock { $0 }
    }

    func append(_ event: String) {
        storage.withLock { $0.append(event) }
    }
}

private final class TestWorld: Sendable {
    private struct State: Sendable {
        let scenario: Scenario
        var target: BSESnapshot
        var sourceReadCount = 0
        var targetReadCount = 0
        var writeCount = 0
    }

    private let storage: Mutex<State>
    private let trace: TestTrace

    init(scenario: Scenario, trace: TestTrace) {
        storage = Mutex(State(
            scenario: scenario,
            target: scenario.targetBefore
        ))
        self.trace = trace
    }

    var sourceReadCount: Int { storage.withLock { $0.sourceReadCount } }
    var targetReadCount: Int { storage.withLock { $0.targetReadCount } }
    var writeCount: Int { storage.withLock { $0.writeCount } }

    func readSource() -> EndToEndSynchronizationReadResult {
        trace.append("sourceRead")
        return storage.withLock {
            $0.sourceReadCount += 1
            return EndToEndSynchronizationReadResult(
                snapshot: $0.scenario.source,
                nativeIdentityObservations: []
            )
        }
    }

    func readTarget() -> EndToEndSynchronizationReadResult {
        trace.append("targetRead")
        return storage.withLock {
            $0.targetReadCount += 1
            return EndToEndSynchronizationReadResult(
                snapshot: $0.target,
                nativeIdentityObservations: []
            )
        }
    }

    func apply(_ operation: SynchronizationOperation) throws {
        trace.append("write")
        try storage.withLock {
            $0.writeCount += 1
            if $0.scenario.adapterFails {
                throw TestFailure.write
            }
            if $0.scenario.adapterUpdatesTarget {
                $0.target = $0.scenario.targetAfter
            }
        }
    }
}

private struct TestReader: EndToEndSynchronizationReading {
    enum Role: Sendable {
        case source
        case target
    }

    let sourceID: BSESourceID
    let role: Role
    let world: TestWorld

    func readForSynchronization() async throws
        -> EndToEndSynchronizationReadResult {
        switch role {
        case .source: world.readSource()
        case .target: world.readTarget()
        }
    }
}

private struct TestMatchingProcessor: EndToEndMatchingProcessing {
    let trace: TestTrace

    func execute(
        request: MatchingPipelineRequest
    ) async throws -> MatchingPipelineResult {
        trace.append("matching")
        let baseline = try Baseline.empty(
            baselineID: BaselineID(UUID(
                uuidString: "F0000000-0000-0000-0000-000000000001"
            )!)
        )
        let logicalSnapshots = request.snapshots.map {
            LogicalSnapshot(
                source: $0.source,
                capturedAt: $0.capturedAt,
                tree: $0.tree
            )
        }
        let reconciliation = IdentityReconciliationReport(
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
            reconciliationReport: reconciliation,
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

private struct TestBootstrapper: EndToEndNativeIdentityBootstrapping {
    let trace: TestTrace

    func bootstrap(
        reconciliationReport: IdentityReconciliationReport,
        observations: [NativeIdentityObservation]
    ) throws -> NativeIdentityBootstrapResult {
        trace.append("bootstrap")
        return NativeIdentityBootstrapResult(
            observationsProcessed: observations.count,
            mappingsCreated: 0,
            mappingsAlreadyPresent: 0,
            conflictsDetected: 0
        )
    }
}

private struct TracedProjector: EndToEndTargetProjecting {
    let trace: TestTrace

    func project(request: ProjectionRequest) throws -> TargetProjection {
        trace.append("projection")
        return try TargetProjector().project(request: request)
    }
}

private struct TracedDiffEngine: EndToEndLogicalDiffing {
    let trace: TestTrace

    func diff(request: LogicalDiffRequest) throws -> LogicalDiffResult {
        trace.append("diff")
        return try LogicalDiffEngine().diff(request: request)
    }
}

private struct TracedPlanner: EndToEndSynchronizationPlanning {
    let trace: TestTrace

    func plan(
        request: SynchronizationPlanningRequest
    ) throws -> SynchronizationPlan {
        trace.append("plan")
        return try SynchronizationPlanner().plan(request: request)
    }
}

private struct TracedExecutor: EndToEndSynchronizationExecuting {
    let trace: TestTrace

    func execute(
        request: SynchronizationExecutionRequest
    ) async -> SynchronizationExecutionResult {
        trace.append("execute")
        return await SynchronizationExecutor().execute(request: request)
    }
}

private struct EndToEndPassthroughIdentityResolver:
    EndToEndNativeIdentityResolving
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

private struct TestWriteAdapter: BookmarkWriteAdapter {
    let identifier = WriteAdapterIdentifier(UUID(
        uuidString: "F0000000-0000-0000-0000-000000000002"
    )!)
    let sourceID: BSESourceID
    let world: TestWorld
    let capabilities = WriteAdapterCapabilities(
        canCreate: true,
        canDelete: true,
        canRename: true,
        canUpdateURL: true,
        canMove: true,
        canReorder: true,
        canArchive: true,
        canDryRun: true
    )

    func execute(
        operation: SynchronizationOperation,
        context: WriteExecutionContext
    ) async throws -> WriteOperationResult {
        try world.apply(operation)
        return WriteOperationResult(
            adapterIdentifier: identifier,
            sourceID: sourceID,
            logicalNodeID: operation.logicalNodeID,
            status: .applied
        )
    }
}

private enum TestFailure: Error {
    case write
}

private func testFolder(
    _ id: Int,
    _ title: String,
    parent: Int? = nil,
    position: Int = 0
) throws -> BSENode {
    try BSENode(
        logicalID: makeLogicalID(id),
        kind: .folder,
        title: title,
        parentID: parent.map(makeLogicalID),
        position: position
    )
}

private func testBookmark(
    _ id: Int,
    _ title: String,
    parent: Int,
    position: Int = 0,
    url: String = "https://example.test"
) throws -> BSENode {
    try BSENode(
        logicalID: makeLogicalID(id),
        kind: .bookmark,
        title: title,
        parentID: makeLogicalID(parent),
        position: position,
        url: URL(string: url)
    )
}

private func makeLogicalID(_ value: Int) -> LogicalNodeID {
    LogicalNodeID(UUID(uuidString: String(
        format: "F1000000-0000-0000-0000-%012d",
        value
    ))!)
}

private func makeSourceID(_ value: Int) -> BSESourceID {
    BSESourceID(UUID(uuidString: String(
        format: "F2000000-0000-0000-0000-%012d",
        value
    ))!)
}
