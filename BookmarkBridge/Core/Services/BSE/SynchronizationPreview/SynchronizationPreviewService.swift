//
//  SynchronizationPreviewService.swift
//  BookmarkBridge
//

import Foundation

/// Production read-only composition from concrete browser readers to an
/// ordered synchronization plan. It never constructs or calls an Executor,
/// WriteAdapter, Store, Mutator, backup service, or atomic writer.
nonisolated struct SynchronizationPreviewService: Sendable {
    private let pipeline: any SynchronizationPipelineExecuting

    init(
        baselineRepository: BaselineRepository,
        identityProvider: any IdentityProvider,
        nativeIdentityRepository: any NativeIdentityRepository
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
    }

    /// Internal seam for deterministic orchestration and error-mapping tests.
    init(pipeline: any SynchronizationPipelineExecuting) {
        self.pipeline = pipeline
    }

    func preview(
        request: SynchronizationPreviewRequest
    ) async throws -> SynchronizationPreviewResult {
        let safariAccess = request.safariBookmarksURL
            .startAccessingSecurityScopedResource()
        let chromeAccess = request.chromeBookmarksURL
            .startAccessingSecurityScopedResource()
        defer {
            if safariAccess {
                request.safariBookmarksURL.stopAccessingSecurityScopedResource()
            }
            if chromeAccess {
                request.chromeBookmarksURL.stopAccessingSecurityScopedResource()
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
                profileIdentifier: request.chromeProfileIdentifier
            )
        )
        let sourceReader: any EndToEndSynchronizationReading
        let targetReader: any EndToEndSynchronizationReading
        let direction: SynchronizationDirection
        switch request.direction {
        case .safariToChrome:
            sourceReader = safariReader
            targetReader = chromeReader
            direction = .oneWay(
                source: request.safariSourceID,
                target: request.chromeSourceID
            )
        case .chromeToSafari:
            sourceReader = chromeReader
            targetReader = safariReader
            direction = .oneWay(
                source: request.chromeSourceID,
                target: request.safariSourceID
            )
        }

        let result: SynchronizationPipelineResult
        do {
            result = try await pipeline.execute(
                request: SynchronizationPipelineRequest(
                    sourceReader: sourceReader,
                    targetReader: targetReader,
                    policy: .allChanges(direction: direction)
                )
            )
        } catch {
            throw mapPipelineError(error)
        }
        return try SynchronizationPreviewResult(
            request: request,
            sourceSnapshot: result.sourceRead.snapshot,
            targetSnapshot: result.targetRead.snapshot,
            logicalDiff: result.logicalDiff,
            plan: result.plan
        )
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
