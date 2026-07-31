//
//  SynchronizationPipeline.swift
//  BookmarkBridge
//

#if DEBUG
import OSLog

nonisolated private let synchronizationPipelineLogger = Logger(
    subsystem: "fr.jerome.BookmarkBridge",
    category: "Synchronization.Pipeline"
)
#endif

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
            #if DEBUG
            synchronizationPipelineLogger.debug(
                "\(PreviewDiagnosticsContext.prefix, privacy: .public) stage=planning status=starting changes=\(analysis.logicalDiff.changes.count, privacy: .public)"
            )
            #endif
            plan = try planner.plan(
                request: SynchronizationPlanningRequest(
                    before: analysis.projection.before,
                    logicalDiff: analysis.logicalDiff,
                    policy: request.policy
                )
            )
        } catch is CancellationError {
            #if DEBUG
            synchronizationPipelineLogger.debug(
                "\(PreviewDiagnosticsContext.prefix, privacy: .public) stage=planning status=cancelled"
            )
            #endif
            throw CancellationError()
        } catch {
            throw SynchronizationPipelineError.planningFailure(
                SynchronizationPipelineFailureContext(error)
            )
        }
        #if DEBUG
        synchronizationPipelineLogger.debug(
            "\(PreviewDiagnosticsContext.prefix, privacy: .public) stage=planning status=success operations=\(plan.phases.flatMap(\.operations).count, privacy: .public)"
        )
        #endif
        return SynchronizationPipelineResult(
            analysis: analysis,
            plan: plan
        )
    }

    func analyze(
        request: SynchronizationPipelineRequest
    ) async throws -> SynchronizationPipelineAnalysis {
        #if DEBUG
        synchronizationPipelineLogger.debug(
            "\(PreviewDiagnosticsContext.prefix, privacy: .public) stage=source-read status=starting"
        )
        #endif
        let sourceRead = try await read(
            request.sourceReader,
            source: true
        )
        #if DEBUG
        synchronizationPipelineLogger.debug(
            "\(PreviewDiagnosticsContext.prefix, privacy: .public) stage=source-read status=success nodes=\(sourceRead.snapshot.tree.count, privacy: .public)"
        )
        synchronizationPipelineLogger.debug(
            "\(PreviewDiagnosticsContext.prefix, privacy: .public) stage=target-read status=starting"
        )
        #endif
        let targetRead = try await read(
            request.targetReader,
            source: false
        )
        #if DEBUG
        synchronizationPipelineLogger.debug(
            "\(PreviewDiagnosticsContext.prefix, privacy: .public) stage=target-read status=success nodes=\(targetRead.snapshot.tree.count, privacy: .public)"
        )
        #endif
        let resolvedSourceRead: EndToEndSynchronizationReadResult
        let resolvedTargetRead: EndToEndSynchronizationReadResult
        do {
            resolvedSourceRead = try identityResolver.resolve(sourceRead)
                .readResult
            resolvedTargetRead = try identityResolver.resolve(targetRead)
                .readResult
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw SynchronizationPipelineError
                .nativeIdentityResolutionFailure(
                    SynchronizationPipelineFailureContext(error)
                )
        }

        let matching: MatchingPipelineResult
        do {
            #if DEBUG
            synchronizationPipelineLogger.debug(
                "\(PreviewDiagnosticsContext.prefix, privacy: .public) stage=matching status=starting"
            )
            #endif
            matching = try await matchingPipeline.execute(
                request: MatchingPipelineRequest(snapshots: [
                    resolvedSourceRead.snapshot,
                    resolvedTargetRead.snapshot,
                ])
            )
            #if DEBUG
            synchronizationPipelineLogger.debug(
                "\(PreviewDiagnosticsContext.prefix, privacy: .public) stage=matching status=success logicalSnapshots=\(matching.logicalSnapshots.count, privacy: .public) groups=\(matching.pipelineReport.matchingGroupCount, privacy: .public) matched=\(matching.pipelineReport.matchedGroupCount, privacy: .public) unmatched=\(matching.pipelineReport.unmatchedGroupCount, privacy: .public) ambiguous=\(matching.pipelineReport.ambiguousGroupCount, privacy: .public) createdIdentities=\(matching.reconciliationReport.createdIdentities.count, privacy: .public) reusedIdentities=\(matching.reconciliationReport.reusedIdentities.count, privacy: .public) unresolved=\(matching.reconciliationReport.unresolvedObjects.count, privacy: .public)"
            )
            #endif
        } catch is CancellationError {
            #if DEBUG
            synchronizationPipelineLogger.debug(
                "\(PreviewDiagnosticsContext.prefix, privacy: .public) stage=matching status=cancelled"
            )
            #endif
            throw CancellationError()
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
        } catch is CancellationError {
            throw CancellationError()
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
            #if DEBUG
            synchronizationPipelineLogger.debug(
                "\(PreviewDiagnosticsContext.prefix, privacy: .public) stage=projection status=starting"
            )
            #endif
            projection = try projector.project(
                request: ProjectionRequest(
                    sourceSnapshot: sourceSnapshot,
                    targetSnapshot: targetSnapshot,
                    policy: request.policy
                )
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw SynchronizationPipelineError.projectionFailure(
                SynchronizationPipelineFailureContext(error)
            )
        }

        let logicalDiff: LogicalDiffResult
        do {
            #if DEBUG
            synchronizationPipelineLogger.debug(
                "\(PreviewDiagnosticsContext.prefix, privacy: .public) stage=diff status=starting"
            )
            #endif
            logicalDiff = try diffEngine.diff(
                request: LogicalDiffRequest(
                    before: projection.before,
                    after: projection.after
                )
            )
            #if DEBUG
            let afterChildren = Dictionary(
                grouping: projection.after.nodes,
                by: \.parentID
            ).mapValues(\.count)
            let sparseAfterNodes = projection.after.nodes.filter { node in
                guard let position = node.position else { return false }
                return position >= afterChildren[node.parentID, default: 0]
            }
            synchronizationPipelineLogger.debug(
                "\(PreviewDiagnosticsContext.prefix, privacy: .public) stage=diff status=success changes=\(logicalDiff.changes.count, privacy: .public) invalidProjectedPositions=\(sparseAfterNodes.count, privacy: .public)"
            )
            #endif
        } catch is CancellationError {
            #if DEBUG
            synchronizationPipelineLogger.debug(
                "\(PreviewDiagnosticsContext.prefix, privacy: .public) stage=diff status=cancelled"
            )
            #endif
            throw CancellationError()
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
        } catch is CancellationError {
            #if DEBUG
            synchronizationPipelineLogger.debug(
                "\(PreviewDiagnosticsContext.prefix, privacy: .public) stage=\(source ? "source-read" : "target-read", privacy: .public) status=cancelled"
            )
            #endif
            throw CancellationError()
        } catch {
            let context = SynchronizationPipelineFailureContext(error)
            #if DEBUG
            synchronizationPipelineLogger.error(
                "\(PreviewDiagnosticsContext.prefix, privacy: .public) stage=\(source ? "source-read" : "target-read", privacy: .public) status=failure type=\(context.errorType, privacy: .public) error=\(context.description, privacy: .public)"
            )
            #endif
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
