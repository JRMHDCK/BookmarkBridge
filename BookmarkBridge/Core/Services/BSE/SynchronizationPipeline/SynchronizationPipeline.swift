//
//  SynchronizationPipeline.swift
//  BookmarkBridge
//

nonisolated protocol SynchronizationMatchingProcessing: Sendable {
    func execute(
        request: MatchingPipelineRequest
    ) async throws -> MatchingPipelineResult
}

nonisolated protocol SynchronizationNativeIdentityBootstrapping: Sendable {
    func bootstrap(
        reconciliationReport: IdentityReconciliationReport,
        observations: [NativeIdentityObservation]
    ) throws -> NativeIdentityBootstrapResult
}

nonisolated protocol SynchronizationNativeIdentityResolving: Sendable {
    func resolve(
        _ readResult: EndToEndSynchronizationReadResult
    ) throws -> NativeIdentityResolutionResult
}

nonisolated protocol SynchronizationTargetProjecting: Sendable {
    func project(request: ProjectionRequest) throws -> TargetProjection
}

nonisolated protocol SynchronizationLogicalDiffing: Sendable {
    func diff(request: LogicalDiffRequest) throws -> LogicalDiffResult
}

nonisolated protocol SynchronizationPlanning: Sendable {
    func plan(
        request: SynchronizationPlanningRequest
    ) throws -> SynchronizationPlan
}

/// Testable boundary consumed by orchestration services.
///
/// The protocol exposes the two existing pipeline paths without moving or
/// duplicating any composition logic.
nonisolated protocol SynchronizationPipelineExecuting: Sendable {
    func execute(
        request: SynchronizationPipelineRequest
    ) async throws -> SynchronizationPipelineResult

    func analyze(
        request: SynchronizationPipelineRequest
    ) async throws -> SynchronizationPipelineAnalysis
}

extension MatchingPipeline: SynchronizationMatchingProcessing {}
extension NativeIdentityResolver: SynchronizationNativeIdentityResolving {}
extension NativeIdentityBootstrapper:
    SynchronizationNativeIdentityBootstrapping {}
extension TargetProjector: SynchronizationTargetProjecting {}
extension LogicalDiffEngine: SynchronizationLogicalDiffing {}
extension SynchronizationPlanner: SynchronizationPlanning {}

/// The single read-only composition from two readers to a deterministic plan.
/// `analyze` intentionally stops before planning so final verification can
/// reuse the exact same chain without producing a second plan.
nonisolated struct SynchronizationPipeline: Sendable {
    private let matchingPipeline: any SynchronizationMatchingProcessing
    private let identityResolver: any SynchronizationNativeIdentityResolving
    private let bootstrapper:
        any SynchronizationNativeIdentityBootstrapping
    private let projector: any SynchronizationTargetProjecting
    private let diffEngine: any SynchronizationLogicalDiffing
    private let planner: any SynchronizationPlanning

    init(
        matchingPipeline: any SynchronizationMatchingProcessing,
        identityResolver: any SynchronizationNativeIdentityResolving,
        bootstrapper: any SynchronizationNativeIdentityBootstrapping,
        projector: any SynchronizationTargetProjecting = TargetProjector(),
        diffEngine: any SynchronizationLogicalDiffing = LogicalDiffEngine(),
        planner: any SynchronizationPlanning = SynchronizationPlanner()
    ) {
        self.matchingPipeline = matchingPipeline
        self.identityResolver = identityResolver
        self.bootstrapper = bootstrapper
        self.projector = projector
        self.diffEngine = diffEngine
        self.planner = planner
    }

    func execute(
        request: SynchronizationPipelineRequest
    ) async throws -> SynchronizationPipelineResult {
        let analysis = try await analyze(request: request)
        let plan: SynchronizationPlan
        do {
            plan = try planner.plan(
                request: SynchronizationPlanningRequest(
                    before: analysis.projection.before,
                    logicalDiff: analysis.logicalDiff,
                    policy: request.policy
                )
            )
        } catch {
            throw SynchronizationPipelineError.planningFailure(
                SynchronizationPipelineFailureContext(error)
            )
        }
        return SynchronizationPipelineResult(
            analysis: analysis,
            plan: plan
        )
    }

    func analyze(
        request: SynchronizationPipelineRequest
    ) async throws -> SynchronizationPipelineAnalysis {
        let sourceRead = try await read(
            request.sourceReader,
            source: true
        )
        let targetRead = try await read(
            request.targetReader,
            source: false
        )
        let resolvedSourceRead: EndToEndSynchronizationReadResult
        let resolvedTargetRead: EndToEndSynchronizationReadResult
        do {
            resolvedSourceRead = try identityResolver.resolve(sourceRead)
                .readResult
            resolvedTargetRead = try identityResolver.resolve(targetRead)
                .readResult
        } catch {
            throw SynchronizationPipelineError
                .nativeIdentityResolutionFailure(
                    SynchronizationPipelineFailureContext(error)
                )
        }

        let matching: MatchingPipelineResult
        do {
            matching = try await matchingPipeline.execute(
                request: MatchingPipelineRequest(snapshots: [
                    resolvedSourceRead.snapshot,
                    resolvedTargetRead.snapshot,
                ])
            )
        } catch {
            throw SynchronizationPipelineError.matchingFailure(
                SynchronizationPipelineFailureContext(error)
            )
        }

        let bootstrap: NativeIdentityBootstrapResult
        do {
            bootstrap = try bootstrapper.bootstrap(
                reconciliationReport: matching.reconciliationReport,
                observations:
                    resolvedSourceRead.nativeIdentityObservations
                    + resolvedTargetRead.nativeIdentityObservations
            )
        } catch {
            throw SynchronizationPipelineError.bootstrapFailure(
                SynchronizationPipelineFailureContext(error)
            )
        }

        let sourceSnapshot = try logicalSnapshot(
            resolvedSourceRead.snapshot.source,
            in: matching.logicalSnapshots
        )
        let targetSnapshot = try logicalSnapshot(
            resolvedTargetRead.snapshot.source,
            in: matching.logicalSnapshots
        )

        let projection: TargetProjection
        do {
            projection = try projector.project(
                request: ProjectionRequest(
                    sourceSnapshot: sourceSnapshot,
                    targetSnapshot: targetSnapshot,
                    policy: request.policy
                )
            )
        } catch {
            throw SynchronizationPipelineError.projectionFailure(
                SynchronizationPipelineFailureContext(error)
            )
        }

        let logicalDiff: LogicalDiffResult
        do {
            logicalDiff = try diffEngine.diff(
                request: LogicalDiffRequest(
                    before: projection.before,
                    after: projection.after
                )
            )
        } catch {
            throw SynchronizationPipelineError.diffFailure(
                SynchronizationPipelineFailureContext(error)
            )
        }

        return SynchronizationPipelineAnalysis(
            sourceRead: sourceRead,
            targetRead: targetRead,
            matching: matching,
            reconciliationReport: matching.reconciliationReport,
            bootstrap: bootstrap,
            projection: projection,
            logicalDiff: logicalDiff
        )
    }

    private func read(
        _ reader: any EndToEndSynchronizationReading,
        source: Bool
    ) async throws -> EndToEndSynchronizationReadResult {
        do {
            return try await reader.readForSynchronization()
        } catch {
            let context = SynchronizationPipelineFailureContext(error)
            if source {
                throw SynchronizationPipelineError.sourceReadFailure(context)
            }
            throw SynchronizationPipelineError.targetReadFailure(context)
        }
    }

    private func logicalSnapshot(
        _ sourceID: BSESourceID,
        in snapshots: [LogicalSnapshot]
    ) throws -> LogicalSnapshot {
        guard let snapshot = snapshots.first(where: {
            $0.source == sourceID
        }) else {
            throw SynchronizationPipelineError
                .missingLogicalSnapshot(sourceID)
        }
        return snapshot
    }
}

extension SynchronizationPipeline: SynchronizationPipelineExecuting {}

// Compatibility aliases keep existing injected test doubles and confirmed
// planning wrappers source-compatible while ownership moves to the shared
// synchronization composition.
typealias EndToEndMatchingProcessing = SynchronizationMatchingProcessing
typealias EndToEndNativeIdentityBootstrapping =
    SynchronizationNativeIdentityBootstrapping
typealias EndToEndNativeIdentityResolving =
    SynchronizationNativeIdentityResolving
typealias EndToEndTargetProjecting = SynchronizationTargetProjecting
typealias EndToEndLogicalDiffing = SynchronizationLogicalDiffing
typealias EndToEndSynchronizationPlanning = SynchronizationPlanning
