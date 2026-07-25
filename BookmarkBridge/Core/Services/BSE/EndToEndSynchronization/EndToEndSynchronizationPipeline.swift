//
//  EndToEndSynchronizationPipeline.swift
//  BookmarkBridge
//

nonisolated protocol EndToEndSynchronizationExecuting: Sendable {
    func execute(
        request: SynchronizationExecutionRequest
    ) async -> SynchronizationExecutionResult
}

extension SynchronizationExecutor: EndToEndSynchronizationExecuting {}

/// Runs one write pass followed by one complete read-only reconstruction.
/// A residual diff is reported and never triggers a second execution.
nonisolated struct EndToEndSynchronizationPipeline: Sendable {
    private let sourceReader: any EndToEndSynchronizationReading
    private let targetReader: any EndToEndSynchronizationReading
    private let synchronizationPipeline: any SynchronizationPipelineExecuting
    private let executor: any EndToEndSynchronizationExecuting
    private let writeAdapter: any BookmarkWriteAdapter

    init(
        sourceReader: any EndToEndSynchronizationReading,
        targetReader: any EndToEndSynchronizationReading,
        matchingPipeline: any EndToEndMatchingProcessing,
        identityResolver: any EndToEndNativeIdentityResolving,
        bootstrapper: any EndToEndNativeIdentityBootstrapping,
        projector: any EndToEndTargetProjecting = TargetProjector(),
        diffEngine: any EndToEndLogicalDiffing = LogicalDiffEngine(),
        planner: any EndToEndSynchronizationPlanning = SynchronizationPlanner(),
        executor: any EndToEndSynchronizationExecuting = SynchronizationExecutor(),
        writeAdapter: any BookmarkWriteAdapter
    ) {
        self.sourceReader = sourceReader
        self.targetReader = targetReader
        synchronizationPipeline = SynchronizationPipeline(
            matchingPipeline: matchingPipeline,
            identityResolver: identityResolver,
            bootstrapper: bootstrapper,
            projector: projector,
            diffEngine: diffEngine,
            planner: planner
        )
        self.executor = executor
        self.writeAdapter = writeAdapter
    }

    /// Internal seam for deterministic orchestration and error-mapping tests.
    init(
        sourceReader: any EndToEndSynchronizationReading,
        targetReader: any EndToEndSynchronizationReading,
        synchronizationPipeline: any SynchronizationPipelineExecuting,
        executor: any EndToEndSynchronizationExecuting = SynchronizationExecutor(),
        writeAdapter: any BookmarkWriteAdapter
    ) {
        self.sourceReader = sourceReader
        self.targetReader = targetReader
        self.synchronizationPipeline = synchronizationPipeline
        self.executor = executor
        self.writeAdapter = writeAdapter
    }

    func execute(
        request: EndToEndSynchronizationRequest
    ) async throws -> EndToEndSynchronizationResult {
        let before: SynchronizationPipelineResult
        do {
            before = try await synchronizationPipeline.execute(
                request: SynchronizationPipelineRequest(
                    sourceReader: sourceReader,
                    targetReader: targetReader,
                    policy: request.synchronizationPolicy
                )
            )
        } catch {
            throw mapPipelineError(error, targetIsVerification: false)
        }
        let sourceRead = before.sourceRead
        let targetReadBefore = before.targetRead
        let plan = before.plan
        let execution = await executor.execute(
            request: SynchronizationExecutionRequest(
                plan: plan,
                adapter: writeAdapter,
                context: request.writeContext,
                policy: request.executionPolicy
            )
        )
        guard execution.status == .completed else {
            throw EndToEndSynchronizationError.executionFailed(
                execution.status
            )
        }

        let after: SynchronizationPipelineAnalysis
        do {
            after = try await synchronizationPipeline.analyze(
                request: SynchronizationPipelineRequest(
                    sourceReader: CachedSynchronizationReader(
                        result: sourceRead
                    ),
                    targetReader: targetReader,
                    policy: request.synchronizationPolicy
                )
            )
        } catch {
            throw mapPipelineError(error, targetIsVerification: true)
        }
        guard after.logicalDiff.changes.isEmpty else {
            throw EndToEndSynchronizationError.residualDiff(
                after.logicalDiff.changes
            )
        }

        return EndToEndSynchronizationResult(
            sourceRead: sourceRead,
            targetReadBefore: targetReadBefore,
            matchingBefore: before.matching,
            bootstrapBefore: before.bootstrap,
            projectionBefore: before.projection,
            diffBefore: before.logicalDiff,
            plan: plan,
            execution: execution,
            targetReadAfter: after.targetRead,
            matchingAfter: after.matching,
            bootstrapAfter: after.bootstrap,
            projectionAfter: after.projection,
            diffAfter: after.logicalDiff
        )
    }

    private func mapPipelineError(
        _ error: any Error,
        targetIsVerification: Bool
    ) -> EndToEndSynchronizationError {
        guard let pipelineError = error as? SynchronizationPipelineError else {
            return .matchingFailure(
                EndToEndSynchronizationFailureContext(error)
            )
        }
        switch pipelineError {
        case .sourceReadFailure(let context):
            return .sourceReadFailure(
                EndToEndSynchronizationFailureContext(context)
            )
        case .targetReadFailure(let context):
            let mapped = EndToEndSynchronizationFailureContext(context)
            return targetIsVerification
                ? .targetRereadFailure(mapped)
                : .targetReadFailure(mapped)
        case .nativeIdentityResolutionFailure(let context):
            return .matchingFailure(
                EndToEndSynchronizationFailureContext(context)
            )
        case .matchingFailure(let context):
            return .matchingFailure(
                EndToEndSynchronizationFailureContext(context)
            )
        case .bootstrapFailure(let context):
            return .bootstrapFailure(
                EndToEndSynchronizationFailureContext(context)
            )
        case .missingLogicalSnapshot(let sourceID):
            return .missingLogicalSnapshot(sourceID)
        case .projectionFailure(let context):
            return .projectionFailure(
                EndToEndSynchronizationFailureContext(context)
            )
        case .diffFailure(let context):
            return .diffFailure(
                EndToEndSynchronizationFailureContext(context)
            )
        case .planningFailure(let context):
            return .planningFailure(
                EndToEndSynchronizationFailureContext(context)
            )
        }
    }
}

nonisolated private struct CachedSynchronizationReader:
    EndToEndSynchronizationReading
{
    let result: EndToEndSynchronizationReadResult

    var sourceID: BSESourceID {
        result.snapshot.source
    }

    func readForSynchronization() async throws
        -> EndToEndSynchronizationReadResult {
        result
    }
}
