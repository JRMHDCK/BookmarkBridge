//
//  SynchronizationExecutionCoordinator.swift
//  BookmarkBridge
//

import Foundation

/// Application composition boundary for an explicitly confirmed production
/// synchronization. It contains no matching, planning, diffing, or writing
/// logic; all execution is delegated to BSE.
nonisolated struct SynchronizationExecutionCoordinator:
    SynchronizationProductionExecuting
{
    private let productionService: ProductionSynchronizationService
    private let safariImportWorkflow: any SafariImportWorkflowPreparing
    private let safariImportDestinationSelector:
        any SafariImportDestinationSelecting
    private let safariBackupDirectoryURL: URL
    private let chromeBackupDirectoryURL: URL

    init(
        productionService: ProductionSynchronizationService,
        safariImportWorkflow: any SafariImportWorkflowPreparing,
        safariImportDestinationSelector:
            any SafariImportDestinationSelecting,
        safariBackupDirectoryURL: URL,
        chromeBackupDirectoryURL: URL
    ) {
        self.productionService = productionService
        self.safariImportWorkflow = safariImportWorkflow
        self.safariImportDestinationSelector =
            safariImportDestinationSelector
        self.safariBackupDirectoryURL = safariBackupDirectoryURL
        self.chromeBackupDirectoryURL = chromeBackupDirectoryURL
    }

    func synchronize(
        preview: SynchronizationPreviewResult
    ) async throws -> SynchronizationProductionExecutionOutcome {
        if preview.direction == .chromeToSafari {
            guard let destinationFileURL = await safariImportDestinationSelector
                .selectDestinationFile() else {
                throw CancellationError()
            }
            let package = try await safariImportWorkflow.prepare(
                preview: preview,
                destinationFileURL: destinationFileURL
            )
            return .safariImportPrepared(package.presentation)
        }

        let previewRequest = preview.request
        let executionRequest = ProductionSynchronizationRequest(
            direction: preview.direction,
            safariSourceID: previewRequest.safariSourceID,
            chromeSourceID: previewRequest.chromeSourceID,
            safariBookmarksURL: previewRequest.safariBookmarksURL,
            chromeBookmarksURL: previewRequest.chromeBookmarksURL,
            safariBackupDirectoryURL: safariBackupDirectoryURL,
            chromeBackupDirectoryURL: chromeBackupDirectoryURL,
            chromeProfileIdentifier:
                previewRequest.chromeProfileIdentifier,
            safariSecurityScopeURL:
                previewRequest.safariSecurityScopeURL,
            chromeSecurityScopeURL:
                previewRequest.chromeSecurityScopeURL,
            safariSelection: previewRequest.safariSelection,
            chromeSelection: previewRequest.chromeSelection
        )
        let confirmedPlan = try ConfirmedSynchronizationPlan(
            confirming: preview,
            executionRequest: executionRequest
        )
        _ = try await productionService.synchronize(
            confirmedPlan: confirmedPlan
        )
        return .synchronized
    }
}

/// Used only when app composition cannot initialize its BSE session.
nonisolated struct UnavailableSynchronizationExecutionCoordinator:
    SynchronizationProductionExecuting
{
    func synchronize(
        preview: SynchronizationPreviewResult
    ) async throws -> SynchronizationProductionExecutionOutcome {
        throw SynchronizationExecutionCompositionError.unavailable
    }
}

nonisolated private enum SynchronizationExecutionCompositionError: Error {
    case unavailable
}
