//
//  SynchronizationPreviewService.swift
//  BookmarkBridge
//

import Foundation
#if DEBUG
import OSLog

nonisolated private let synchronizationPreviewLogger = Logger(
    subsystem: "fr.jerome.BookmarkBridge",
    category: "Synchronization.Preview"
)
#endif

/// Production read-only composition from concrete browser readers to an
/// ordered synchronization plan. It never constructs or calls an Executor,
/// WriteAdapter, Store, Mutator, backup service, or atomic writer.
nonisolated struct SynchronizationPreviewService: Sendable {
    private let pipeline: any SynchronizationPipelineExecuting
    private let fileController: any SecurityScopedFileControlling

    init(
        baselineRepository: BaselineRepository,
        identityProvider: any IdentityProvider,
        nativeIdentityRepository: any NativeIdentityRepository,
        fileController: any SecurityScopedFileControlling =
            SystemSecurityScopedFileController()
    ) {
        pipeline = SynchronizationPipeline(
            matchingPipeline: MatchingPipeline(
                baselineRepository: baselineRepository,
                matchingEngine: MatchingEngine(),
                groupBuilder: DefaultIdentityMatchingGroupBuilder(),
                reconciliationEngine: IdentityReconciliationEngine(
                    identityProvider: identityProvider,
                    matchingPolicy: StrictIdentityMatchingPolicy(),
                    snapshotBuilder: LogicalSnapshotBuilder()
                )
            ),
            identityResolver: NativeIdentityResolver(
                repository: nativeIdentityRepository
            ),
            bootstrapper: NativeIdentityBootstrapper(
                repository: nativeIdentityRepository
            )
        )
        self.fileController = fileController
    }

    /// Internal seam for deterministic orchestration and error-mapping tests.
    init(
        pipeline: any SynchronizationPipelineExecuting,
        fileController: any SecurityScopedFileControlling =
            SystemSecurityScopedFileController()
    ) {
        self.pipeline = pipeline
        self.fileController = fileController
    }

    func preview(
        request: SynchronizationPreviewRequest
    ) async throws -> SynchronizationPreviewResult {
        #if DEBUG
        synchronizationPreviewLogger.debug(
            "\(PreviewDiagnosticsContext.prefix, privacy: .public) stage=preview status=starting direction=\(String(describing: request.direction), privacy: .public)"
        )
        #endif
        let safariAccess = fileController.startAccessing(
            request.safariSecurityScopeURL
        )
        let chromeAccess = fileController.startAccessing(
            request.chromeSecurityScopeURL
        )
        #if DEBUG
        synchronizationPreviewLogger.debug(
            "\(PreviewDiagnosticsContext.prefix, privacy: .public) stage=security-scope status=opened safari=\(safariAccess, privacy: .public) chrome=\(chromeAccess, privacy: .public) chromeUsesAuthorizedDirectory=\(request.chromeSecurityScopeURL != request.chromeBookmarksURL, privacy: .public)"
        )
        #endif
        defer {
            if safariAccess {
                fileController.stopAccessing(
                    request.safariSecurityScopeURL
                )
            }
            if chromeAccess {
                fileController.stopAccessing(
                    request.chromeSecurityScopeURL
                )
            }
        }

        let safariReader = SafariAdapter(
            sourceID: request.safariSourceID,
            dataSource: DefaultSafariDataSource(
                bookmarksFileURL: request.safariBookmarksURL
            )
        )
        let chromeReader = ChromeAdapter(
            sourceID: request.chromeSourceID,
            profileIdentifier: request.chromeProfileIdentifier,
            dataSource: DefaultChromeDataSource(
                bookmarksFileURL: request.chromeBookmarksURL,
                profileIdentifier: request.chromeProfileIdentifier,
                securityScopeURL: request.chromeSecurityScopeURL
            )
        )
        let sourceReader: any EndToEndSynchronizationReading
        let targetReader: any EndToEndSynchronizationReading
        let direction: SynchronizationDirection
        switch request.direction {
        case .safariToChrome:
            sourceReader = SelectionScopedSynchronizationReader(
                reader: safariReader,
                selection: request.safariSelection
            )
            targetReader = SelectionScopedSynchronizationReader(
                reader: chromeReader,
                selection: request.chromeSelection
            )
            direction = .oneWay(
                source: request.safariSourceID,
                target: request.chromeSourceID
            )
        case .chromeToSafari:
            sourceReader = SelectionScopedSynchronizationReader(
                reader: chromeReader,
                selection: request.chromeSelection
            )
            targetReader = SelectionScopedSynchronizationReader(
                reader: safariReader,
                selection: request.safariSelection
            )
            direction = .oneWay(
                source: request.chromeSourceID,
                target: request.safariSourceID
            )
        }

        let result: SynchronizationPipelineResult
        do {
            #if DEBUG
            synchronizationPreviewLogger.debug(
                "\(PreviewDiagnosticsContext.prefix, privacy: .public) stage=pipeline status=starting"
            )
            #endif
            result = try await pipeline.execute(
                request: SynchronizationPipelineRequest(
                    sourceReader: sourceReader,
                    targetReader: targetReader,
                    policy: .allChanges(direction: direction)
                )
            )
        } catch is CancellationError {
            #if DEBUG
            synchronizationPreviewLogger.debug(
                "\(PreviewDiagnosticsContext.prefix, privacy: .public) stage=pipeline status=cancelled"
            )
            #endif
            throw CancellationError()
        } catch {
            let mapped = mapPipelineError(error)
            #if DEBUG
            synchronizationPreviewLogger.error(
                "\(PreviewDiagnosticsContext.prefix, privacy: .public) stage=pipeline status=failure original=\(PreviewDiagnosticsContext.errorDescription(error), privacy: .public) mapped=\(String(reflecting: mapped), privacy: .public)"
            )
            #endif
            throw mapped
        }
        try SynchronizationPreviewSafetyValidator().validate(
            before: result.projection.before,
            after: result.projection.after,
            plan: result.plan
        )
        let preview = try SynchronizationPreviewResult(
            request: request,
            sourceSnapshot: result.sourceRead.snapshot,
            targetSnapshot: result.targetRead.snapshot,
            logicalDiff: result.logicalDiff,
            plan: result.plan
        )
        #if DEBUG
        synchronizationPreviewLogger.debug(
            "\(PreviewDiagnosticsContext.prefix, privacy: .public) stage=preview status=success sourceNodes=\(result.sourceRead.snapshot.tree.count, privacy: .public) targetNodes=\(result.targetRead.snapshot.tree.count, privacy: .public) changes=\(result.logicalDiff.changes.count, privacy: .public) operations=\(preview.totalOperationCount, privacy: .public) sourceHash=\(preview.sourceSnapshotFingerprint.rawValue, privacy: .public) targetHash=\(preview.targetSnapshotFingerprint.rawValue, privacy: .public) planHash=\(preview.planFingerprint.rawValue, privacy: .public)"
        )
        #endif
        return preview
    }

    private func mapPipelineError(
        _ error: any Error
    ) -> SynchronizationPreviewError {
        guard let pipelineError = error as? SynchronizationPipelineError else {
            return .matchingFailure(
                SynchronizationPreviewFailureContext(error)
            )
        }
        switch pipelineError {
        case .sourceReadFailure(let context):
            return .sourceReadFailure(
                SynchronizationPreviewFailureContext(context)
            )
        case .targetReadFailure(let context):
            return .targetReadFailure(
                SynchronizationPreviewFailureContext(context)
            )
        case .nativeIdentityResolutionFailure(let context):
            return .matchingFailure(
                SynchronizationPreviewFailureContext(context)
            )
        case .matchingFailure(let context):
            return .matchingFailure(
                SynchronizationPreviewFailureContext(context)
            )
        case .bootstrapFailure(let context):
            return .bootstrapFailure(
                SynchronizationPreviewFailureContext(context)
            )
        case .missingLogicalSnapshot(let sourceID):
            return .missingLogicalSnapshot(sourceID)
        case .projectionFailure(let context):
            return .projectionFailure(
                SynchronizationPreviewFailureContext(context)
            )
        case .diffFailure(let context):
            return .diffFailure(
                SynchronizationPreviewFailureContext(context)
            )
        case .planningFailure(let context):
            return .planningFailure(
                SynchronizationPreviewFailureContext(context)
            )
        }
    }
}
