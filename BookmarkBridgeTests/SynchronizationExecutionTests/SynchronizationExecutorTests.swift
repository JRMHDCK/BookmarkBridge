//
//  SynchronizationExecutorTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("BSE Synchronization Executor")
struct SynchronizationExecutorTests {
    @Test("Phases and operations execute sequentially in exact plan order")
    func exactSequentialOrder() async {
        let operations = ExecutionTestSupport.operations
        let plan = ExecutionTestSupport.plan(
            preparation: [operations[0]],
            structural: [operations[1], operations[2]],
            content: [operations[3]],
            cleanup: [operations[4]]
        )
        let adapter = ControlledExecutionAdapter(
            capabilities: ExecutionTestSupport.allCapabilities,
            outcomes: [
                operations[0]: .status(.applied),
                operations[1]: .status(.alreadySatisfied),
                operations[2]: .status(.simulated),
                operations[3]: .status(.applied),
                operations[4]: .status(.alreadySatisfied),
            ]
        )

        let result = await ExecutionTestSupport.execute(
            plan: plan,
            adapter: adapter,
            policy: .continueAfterFailure
        )

        #expect(await adapter.invocations == plan.operations)
        #expect(result.phaseResults.map(\.phase) == [
            .preparation, .structural, .content, .cleanup,
        ])
        #expect(result.operationResults.map(\.operation) == plan.operations)
        #expect(result.operationResults.map(\.status) == [
            .applied, .alreadySatisfied, .simulated, .applied, .alreadySatisfied,
        ])
        #expect(result.status == .completed)
        #expect(result.report.plannedOperationCount == 5)
        #expect(result.report.attemptedOperationCount == 5)
        #expect(result.report.appliedOperationCount == 2)
        #expect(result.report.alreadySatisfiedOperationCount == 2)
        #expect(result.report.simulatedOperationCount == 1)
        #expect(result.report.completedPhaseCount == 4)
    }

    @Test("An unsupported operation is refused before adapter invocation")
    func unsupportedCapability() async {
        let create = ExecutionTestSupport.operations[0]
        let rename = ExecutionTestSupport.operations[2]
        let adapter = ControlledExecutionAdapter(
            capabilities: ExecutionTestSupport.capabilities(canCreate: false),
            outcomes: [rename: .status(.applied)]
        )

        let result = await ExecutionTestSupport.execute(
            plan: ExecutionTestSupport.plan(structural: [create, rename]),
            adapter: adapter,
            policy: .continueAfterFailure
        )

        #expect(await adapter.invocations == [rename])
        #expect(result.operationResults[0].operation == create)
        #expect(result.operationResults[0].status == .refused)
        #expect(result.operationResults[0].error == .unsupportedCapability(.create))
        #expect(result.operationResults[0].adapterResult == nil)
        #expect(result.operationResults[1].status == .applied)
        #expect(result.status == .completedWithFailures)
        #expect(result.report.refusedOperationCount == 1)
        #expect(result.report.attemptedOperationCount == 1)
    }

    @Test("Dry-run support is checked independently before every operation")
    func unsupportedDryRun() async {
        let operations = Array(ExecutionTestSupport.operations.prefix(2))
        let adapter = ControlledExecutionAdapter(
            capabilities: ExecutionTestSupport.capabilities(canDryRun: false)
        )

        let result = await ExecutionTestSupport.execute(
            plan: ExecutionTestSupport.plan(structural: operations),
            adapter: adapter,
            mode: .dryRun,
            policy: .continueAfterFailure
        )

        #expect(await adapter.invocations.isEmpty)
        #expect(result.operationResults.count == 2)
        #expect(result.operationResults.allSatisfy { $0.status == .refused })
        #expect(result.operationResults.allSatisfy {
            $0.error == .unsupportedCapability(.dryRun)
        })
    }

    @Test("Stop-on-first-failure prevents every following operation and phase")
    func stopOnFirstFailure() async {
        let operations = ExecutionTestSupport.operations
        let first = operations[0]
        let adapter = ControlledExecutionAdapter(
            capabilities: ExecutionTestSupport.allCapabilities,
            outcomes: [first: .failure(.executionFailed(.create))]
        )
        let plan = ExecutionTestSupport.plan(
            preparation: [first, operations[1]],
            structural: [operations[2]]
        )

        let result = await ExecutionTestSupport.execute(
            plan: plan,
            adapter: adapter,
            policy: .stopOnFirstFailure
        )

        #expect(await adapter.invocations == [first])
        #expect(result.status == .stoppedOnFailure)
        #expect(result.phaseResults.count == 1)
        #expect(result.operationResults.count == 1)
        #expect(result.operationResults[0].status == .failed)
        #expect(result.operationResults[0].error == .adapterFailure(
            .executionFailed(.create)
        ))
        #expect(result.report.failedOperationCount == 1)
    }

    @Test("Continue-after-failure preserves the failure and executes the remainder")
    func continueAfterFailure() async {
        let operations = Array(ExecutionTestSupport.operations.prefix(3))
        let adapter = ControlledExecutionAdapter(
            capabilities: ExecutionTestSupport.allCapabilities,
            outcomes: [
                operations[0]: .status(.applied),
                operations[1]: .failure(.sourceUnavailable(
                    sourceID: ExecutionTestSupport.sourceID
                )),
                operations[2]: .status(.alreadySatisfied),
            ]
        )

        let result = await ExecutionTestSupport.execute(
            plan: ExecutionTestSupport.plan(structural: operations),
            adapter: adapter,
            policy: .continueAfterFailure
        )

        #expect(await adapter.invocations == operations)
        #expect(result.operationResults.map(\.status) == [
            .applied, .failed, .alreadySatisfied,
        ])
        #expect(result.status == .completedWithFailures)
        #expect(result.phaseResults.first {
            $0.phase == .structural
        }?.status == .completedWithFailures)
    }

    @Test("An unknown adapter error remains a typed execution failure")
    func unexpectedAdapterError() async {
        let operation = ExecutionTestSupport.operations[3]
        let adapter = ControlledExecutionAdapter(
            capabilities: ExecutionTestSupport.allCapabilities,
            outcomes: [operation: .unexpectedFailure]
        )

        let result = await ExecutionTestSupport.execute(
            plan: ExecutionTestSupport.plan(content: [operation]),
            adapter: adapter,
            policy: .stopOnFirstFailure
        )

        #expect(result.operationResults[0].error == .unexpectedAdapterFailure(.updateURL))
        #expect(result.status == .stoppedOnFailure)
    }

    @Test("Cancellation stops sequencing without retry or rollback")
    func cancellation() async {
        let operations = Array(ExecutionTestSupport.operations.prefix(2))
        let adapter = ControlledExecutionAdapter(
            capabilities: ExecutionTestSupport.allCapabilities,
            outcomes: [operations[0]: .suspendUntilCancelled]
        )
        let task = Task {
            await ExecutionTestSupport.execute(
                plan: ExecutionTestSupport.plan(structural: operations),
                adapter: adapter,
                policy: .continueAfterFailure
            )
        }

        while !(await adapter.hasStarted) {
            await Task.yield()
        }
        task.cancel()
        let result = await task.value

        #expect(await adapter.invocations == [operations[0]])
        #expect(result.status == .cancelled)
        #expect(result.operationResults.count == 1)
        #expect(result.operationResults[0].status == .cancelled)
        #expect(result.operationResults[0].error == .cancelled)
        #expect(result.report.cancelledOperationCount == 1)
    }

    @Test("An empty plan completes without invoking the adapter")
    func emptyPlan() async {
        let adapter = ControlledExecutionAdapter(
            capabilities: ExecutionTestSupport.allCapabilities
        )

        let result = await ExecutionTestSupport.execute(
            plan: ExecutionTestSupport.plan(),
            adapter: adapter,
            policy: .stopOnFirstFailure
        )

        #expect(result.status == .completed)
        #expect(result.phaseResults.map(\.phase) == [
            .preparation, .structural, .content, .cleanup,
        ])
        #expect(result.operationResults.isEmpty)
        #expect(await adapter.invocations.isEmpty)
    }

    @Test("Execution models and existential adapter cross concurrency boundaries")
    func strictConcurrency() {
        let adapter = ControlledExecutionAdapter(
            capabilities: ExecutionTestSupport.allCapabilities
        )
        let request = ExecutionTestSupport.request(
            plan: ExecutionTestSupport.plan(),
            adapter: adapter,
            policy: .stopOnFirstFailure
        )

        requireSendable(SynchronizationExecutor())
        requireSendable(request)
        requireSendable(adapter as any BookmarkWriteAdapter)
        requireSendable(SynchronizationExecutionPolicy.continueAfterFailure)
        requireSendable(SynchronizationExecutionError.cancelled)
    }

    private func requireSendable<T: Sendable>(_ value: T) { _ = value }
}

private nonisolated enum ControlledExecutionOutcome: Sendable {
    case status(WriteOperationStatus)
    case failure(WriteAdapterError)
    case unexpectedFailure
    case suspendUntilCancelled
}

private nonisolated enum ControlledUnexpectedError: Error {
    case failed
}

private actor ControlledExecutionAdapter: BookmarkWriteAdapter {
    nonisolated let identifier = ExecutionTestSupport.adapterID
    nonisolated let capabilities: WriteAdapterCapabilities

    private let outcomes: [SynchronizationOperation: ControlledExecutionOutcome]
    private(set) var invocations: [SynchronizationOperation] = []
    private(set) var hasStarted = false

    init(
        capabilities: WriteAdapterCapabilities,
        outcomes: [SynchronizationOperation: ControlledExecutionOutcome] = [:]
    ) {
        self.capabilities = capabilities
        self.outcomes = outcomes
    }

    func execute(
        operation: SynchronizationOperation,
        context: WriteExecutionContext
    ) async throws -> WriteOperationResult {
        invocations.append(operation)
        hasStarted = true

        switch outcomes[operation] ?? .status(defaultStatus(for: context.mode)) {
        case .status(let status):
            return WriteOperationResult(
                adapterIdentifier: identifier,
                sourceID: context.sourceID,
                logicalNodeID: operation.logicalNodeID,
                status: status
            )
        case .failure(let error):
            throw error
        case .unexpectedFailure:
            throw ControlledUnexpectedError.failed
        case .suspendUntilCancelled:
            try await Task.sleep(for: .seconds(60))
            throw ControlledUnexpectedError.failed
        }
    }

    private func defaultStatus(for mode: WriteExecutionMode) -> WriteOperationStatus {
        mode == .dryRun ? .simulated : .applied
    }
}

private nonisolated enum ExecutionTestSupport {
    static let adapterID = WriteAdapterIdentifier(uuid(900))
    static let sourceID = BSESourceID(uuid(901))

    static let allCapabilities = capabilities()

    static let operations: [SynchronizationOperation] = [
        .create(CreateNodeOperation(
            logicalNodeID: logicalID(1),
            kind: .folder,
            title: "Folder",
            url: nil,
            parentID: nil,
            position: 0
        )),
        .move(MoveNodeOperation(
            logicalNodeID: logicalID(2),
            parentID: logicalID(1)
        )),
        .rename(RenameNodeOperation(
            logicalNodeID: logicalID(3),
            title: "Renamed"
        )),
        .updateURL(UpdateURLOperation(
            logicalNodeID: logicalID(4),
            url: URL(string: "https://example.test/updated")!
        )),
        .delete(DeleteNodeOperation(logicalNodeID: logicalID(5))),
        .reorder(ReorderNodeOperation(logicalNodeID: logicalID(6), position: 2)),
        .archive(ArchiveNodeOperation(
            logicalNodeID: logicalID(7),
            state: .archived
        )),
    ]

    static func execute(
        plan: SynchronizationPlan,
        adapter: any BookmarkWriteAdapter,
        mode: WriteExecutionMode = .apply,
        policy: SynchronizationExecutionPolicy
    ) async -> SynchronizationExecutionResult {
        await SynchronizationExecutor().execute(request: request(
            plan: plan,
            adapter: adapter,
            mode: mode,
            policy: policy
        ))
    }

    static func request(
        plan: SynchronizationPlan,
        adapter: any BookmarkWriteAdapter,
        mode: WriteExecutionMode = .apply,
        policy: SynchronizationExecutionPolicy
    ) -> SynchronizationExecutionRequest {
        SynchronizationExecutionRequest(
            plan: plan,
            adapter: adapter,
            context: WriteExecutionContext(sourceID: sourceID, mode: mode),
            policy: policy
        )
    }

    static func plan(
        preparation: [SynchronizationOperation] = [],
        structural: [SynchronizationOperation] = [],
        content: [SynchronizationOperation] = [],
        cleanup: [SynchronizationOperation] = []
    ) -> SynchronizationPlan {
        let phases: [SynchronizationPhase] = [
            .preparation(preparation),
            .structural(structural),
            .content(content),
            .cleanup(cleanup),
        ]
        return SynchronizationPlan(
            phases: phases,
            report: SynchronizationPlanningReport(
                policy: .allChanges,
                inputChangeCount: phases.flatMap(\.operations).count,
                plannedOperationCount: phases.flatMap(\.operations).count,
                skippedChangeCount: 0,
                preparationOperationCount: preparation.count,
                structuralOperationCount: structural.count,
                contentOperationCount: content.count,
                cleanupOperationCount: cleanup.count
            )
        )
    }

    static func capabilities(
        canCreate: Bool = true,
        canDelete: Bool = true,
        canRename: Bool = true,
        canUpdateURL: Bool = true,
        canMove: Bool = true,
        canReorder: Bool = true,
        canArchive: Bool = true,
        canDryRun: Bool = true
    ) -> WriteAdapterCapabilities {
        WriteAdapterCapabilities(
            canCreate: canCreate,
            canDelete: canDelete,
            canRename: canRename,
            canUpdateURL: canUpdateURL,
            canMove: canMove,
            canReorder: canReorder,
            canArchive: canArchive,
            canDryRun: canDryRun
        )
    }

    static func logicalID(_ value: Int) -> LogicalNodeID {
        LogicalNodeID(uuid(value))
    }

    static func uuid(_ value: Int) -> UUID {
        UUID(uuidString: String(
            format: "00000000-0000-0000-0000-%012d",
            value
        ))!
    }
}
