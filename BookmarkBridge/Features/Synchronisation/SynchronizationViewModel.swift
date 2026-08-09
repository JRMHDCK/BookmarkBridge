//
//  SynchronizationViewModel.swift
//  BookmarkBridge
//

import Foundation
import Observation
#if DEBUG
import OSLog

private let synchronizationViewModelLogger = Logger(
    subsystem: "fr.jerome.BookmarkBridge",
    category: "Synchronization.ViewModel"
)
#endif

/// Read-only boundary used by the UI. The concrete BSE preview service
/// conforms without introducing a UI dependency into Core.
nonisolated protocol SynchronizationPreviewProviding: Sendable {
    func preview(
        request: SynchronizationPreviewRequest
    ) async throws -> SynchronizationPreviewResult
}

extension SynchronizationPreviewService: SynchronizationPreviewProviding {}

/// Executes exactly the BSE preview that the user has seen. The concrete app
/// implementation confirms the plan and delegates to
/// `ProductionSynchronizationService`; tests inject a deterministic double.
nonisolated protocol SynchronizationProductionExecuting: Sendable {
    func synchronize(
        preview: SynchronizationPreviewResult
    ) async throws
}

/// Builds the file- and profile-specific BSE request outside the ViewModel.
/// Production resolves authorized locations; tests provide an in-memory double.
nonisolated protocol SynchronizationPreviewRequestProviding: Sendable {
    func makeRequest(
        safariSource: BookmarkSource,
        chromeSource: BookmarkSource,
        direction: ProductionSynchronizationDirection
    ) async throws -> SynchronizationPreviewRequest
}

/// Read-only source statistics already computed from a loaded bookmark tree.
nonisolated struct SynchronizationSourceSummary:
    Hashable,
    Sendable
{
    let source: BookmarkSource
    let bookmarkCount: Int
    let folderCount: Int

    init(source: BookmarkSource, summary: BrowserBookmarkSummary) {
        self.source = source
        bookmarkCount = summary.bookmarkCount
        folderCount = summary.folderCount
    }
}

/// Presentation-only source data. No BSE model crosses this boundary.
nonisolated struct SynchronizationBrowserSummary:
    Hashable,
    Sendable
{
    let name: String
    let bookmarkCount: Int
    let folderCount: Int
}

/// Presentation-only preview consumed by SwiftUI.
nonisolated struct SynchronizationPreviewPresentation: Hashable, Sendable {
    let source: SynchronizationBrowserSummary
    let target: SynchronizationBrowserSummary
    let totalOperationCount: Int
    let creationCount: Int
    let deletionCount: Int
    let moveCount: Int
    let renameCount: Int
    let urlModificationCount: Int
}

/// Drives the synchronization preview and execution state shown by the
/// synchronization feature.
///
/// It owns no browser or file dependency: request construction and BSE preview
/// execution are both injected. Its observable state contains UI models only.
@MainActor
@Observable
final class SynchronizationViewModel {
    enum State: Hashable {
        case idle
        case loading
        case loaded(SynchronizationPreviewPresentation)
        case empty(SynchronizationPreviewPresentation)
        case failed(String)
    }

    /// Extensible presentation phases. Production currently exposes a single
    /// awaited operation, while the UI contract is ready for finer-grained
    /// preparation, browser-writing, and validation progress later.
    enum ExecutionState: Hashable {
        case idle
        case preparing
        case writing
        case validating
        case completed
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var executionState: ExecutionState = .idle
    private(set) var previewDirection: ProductionSynchronizationDirection?
    let selection: SynchronizationSelectionViewModel
    let directionNavigation: SynchronizationDirectionNavigation

    var isSynchronizing: Bool {
        switch executionState {
        case .preparing, .writing, .validating:
            true
        case .idle, .completed, .failed:
            false
        }
    }

    var canSynchronize: Bool {
        guard executionService != nil, !isSynchronizing else {
            return false
        }
        if case .loaded = state {
            return latestPreviewResult != nil
        }
        return false
    }

    private let previewService: any SynchronizationPreviewProviding
    private let requestProvider: any SynchronizationPreviewRequestProviding
    private let executionService: (any SynchronizationProductionExecuting)?
    private var latestPreviewResult: SynchronizationPreviewResult?
    private var latestSources: (
        safari: SynchronizationSourceSummary,
        chrome: SynchronizationSourceSummary
    )?
    #if DEBUG
    private var activePreviewAttempts: Set<String> = []
    #endif

    init(
        previewService: any SynchronizationPreviewProviding,
        requestProvider: any SynchronizationPreviewRequestProviding,
        executionService:
            (any SynchronizationProductionExecuting)? = nil,
        preferencesStore: any SynchronizationPreferencesStoring =
            InMemorySynchronizationPreferencesStore()
    ) {
        self.previewService = previewService
        self.requestProvider = requestProvider
        self.executionService = executionService
        selection = SynchronizationSelectionViewModel(
            preferencesStore: preferencesStore
        )
        directionNavigation = SynchronizationDirectionNavigation(
            preferencesStore: preferencesStore
        )
    }

    func reset() {
        state = .idle
        executionState = .idle
        latestPreviewResult = nil
        latestSources = nil
        previewDirection = nil
    }

    func configureSelection(sources: [SearchableSource]) {
        selection.configure(sources: sources)
    }

    func loadPreview(
        safari: SynchronizationSourceSummary,
        chrome: SynchronizationSourceSummary,
        direction: ProductionSynchronizationDirection = .safariToChrome
    ) async {
        #if DEBUG
        let attemptID = String(UUID().uuidString.prefix(8))
        let replacedAttempts = activePreviewAttempts.sorted()
        activePreviewAttempts.insert(attemptID)
        synchronizationViewModelLogger.notice(
            "[Preview \(attemptID, privacy: .public)] START activeBefore=\(replacedAttempts.joined(separator: ","), privacy: .public)"
        )
        await PreviewDiagnosticsContext.$attemptID.withValue(attemptID) {
            await performLoadPreview(
                safari: safari,
                chrome: chrome,
                direction: direction
            )
        }
        activePreviewAttempts.remove(attemptID)
        synchronizationViewModelLogger.notice(
            "[Preview \(attemptID, privacy: .public)] END"
        )
        #else
        await performLoadPreview(
            safari: safari,
            chrome: chrome,
            direction: direction
        )
        #endif
    }

    private func performLoadPreview(
        safari: SynchronizationSourceSummary,
        chrome: SynchronizationSourceSummary,
        direction: ProductionSynchronizationDirection
    ) async {
        #if DEBUG
        synchronizationViewModelLogger.debug(
            "\(PreviewDiagnosticsContext.prefix, privacy: .public) stage=load-preview status=starting safariState=loaded safariFolders=\(safari.folderCount, privacy: .public) safariBookmarks=\(safari.bookmarkCount, privacy: .public) safariSource=\(String(describing: safari.source.id), privacy: .public) chromeState=loaded chromeFolders=\(chrome.folderCount, privacy: .public) chromeBookmarks=\(chrome.bookmarkCount, privacy: .public) chromeProfile=\(chrome.source.id.profile ?? "none", privacy: .public) chromeSource=\(String(describing: chrome.source.id), privacy: .public)"
        )
        #endif
        state = .loading
        latestSources = (safari, chrome)
        do {
            let baseRequest = try await requestProvider.makeRequest(
                safariSource: safari.source,
                chromeSource: chrome.source,
                direction: direction
            )
            let request = baseRequest.selecting(
                safari: selection.scope(for: safari.source.id),
                chrome: selection.scope(for: chrome.source.id)
            )
            #if DEBUG
            synchronizationViewModelLogger.debug(
                "\(PreviewDiagnosticsContext.prefix, privacy: .public) stage=request status=created direction=\(String(describing: request.direction), privacy: .public) safariSourceID=\(request.safariSourceID.description, privacy: .public) chromeSourceID=\(request.chromeSourceID.description, privacy: .public) chromeProfile=\(request.chromeProfileIdentifier.rawValue, privacy: .public) usesChromeDirectoryScope=\(request.chromeSecurityScopeURL != request.chromeBookmarksURL, privacy: .public)"
            )
            #endif
            let result = try await previewService.preview(request: request)
            latestPreviewResult = result
            previewDirection = result.direction
            let preview = Self.makePreview(
                result: result,
                safari: safari,
                chrome: chrome
            )
            state = result.totalOperationCount == 0
                ? .empty(preview)
                : .loaded(preview)
            #if DEBUG
            synchronizationViewModelLogger.debug(
                "\(PreviewDiagnosticsContext.prefix, privacy: .public) stage=load-preview status=success operations=\(result.totalOperationCount, privacy: .public)"
            )
            #endif
        } catch is CancellationError {
            #if DEBUG
            synchronizationViewModelLogger.debug(
                "\(PreviewDiagnosticsContext.prefix, privacy: .public) stage=load-preview status=cancelled replacementActive=\(self.activePreviewAttempts.count > 1, privacy: .public)"
            )
            #endif
            state = .idle
            latestPreviewResult = nil
            previewDirection = nil
        } catch {
            #if DEBUG
            synchronizationViewModelLogger.error(
                "\(PreviewDiagnosticsContext.prefix, privacy: .public) stage=load-preview status=failure \(PreviewDiagnosticsContext.errorDescription(error), privacy: .public)"
            )
            #endif
            state = .failed(
                "Impossible de calculer la prévisualisation."
            )
            latestPreviewResult = nil
            previewDirection = nil
        }
    }

    /// Executes the last valid, user-visible preview once. A second call made
    /// while the first is suspended is ignored. On success the preview is
    /// recomputed automatically; on failure the last valid preview is retained.
    @discardableResult
    func synchronize() async -> Bool {
        guard !isSynchronizing,
              let executionService,
              let preview = latestPreviewResult,
              let sources = latestSources,
              preview.totalOperationCount > 0 else {
            return false
        }

        executionState = .preparing
        do {
            executionState = .writing
            try await executionService.synchronize(preview: preview)
            executionState = .validating
            await loadPreview(
                safari: sources.safari,
                chrome: sources.chrome,
                direction: preview.direction
            )
            executionState = .completed
            return true
        } catch is CancellationError {
            executionState = .failed(
                "La synchronisation a été annulée."
            )
            return false
        } catch {
            #if DEBUG
            synchronizationViewModelLogger.error(
                "stage=synchronize status=failure \(PreviewDiagnosticsContext.errorDescription(error), privacy: .public)"
            )
            #endif
            executionState = .failed(
                Self.executionFailureDescription(error)
            )
            return false
        }
    }

    private static func executionFailureDescription(
        _ error: any Error
    ) -> String {
        guard let transactionError = error as? SynchronizationTransactionError
        else {
            return [
                "La synchronisation a échoué.",
                "\(String(reflecting: type(of: error))): \(String(describing: error))",
            ].joined(separator: " ")
        }
        switch transactionError {
        case .finalValidationFailed(let failure):
            return [
                "La validation finale a détecté des différences résiduelles.",
                "Cause : \(conciseCause(failure.cause))",
                "La sauvegarde a été restaurée.",
            ].joined(separator: " ")
        case .restorationFailed(let failure):
            let restorationFailures = failure.restorationFailures.map {
                "\(restorationTargetDescription($0.target)) : "
                    + conciseCause($0.context)
            }.joined(separator: " ; ")
            return [
                "La synchronisation a échoué après \(failure.appliedOperationCount) opération(s).",
                "Cause initiale : \(conciseCause(failure.cause))",
                "La restauration automatique a échoué.",
                restorationFailures.isEmpty
                    ? "Le détail de restauration est indisponible."
                    : "Détail : \(restorationFailures).",
                "Fermez Safari et Chrome avant de réessayer.",
            ].joined(separator: " ")
        case .executionFailed(let failure):
            return "L’écriture a échoué : \(conciseCause(failure.cause))"
        case .backupCreationFailed(let context):
            return "La sauvegarde obligatoire n’a pas pu être créée : \(conciseCause(context))"
        case .participantCaptureFailed(let participant, let context):
            return "Le point de restauration \(participant) n’a pas pu être créé : \(conciseCause(context))"
        }
    }

    private static func conciseCause(
        _ context: SynchronizationTransactionFailureContext
    ) -> String {
        if context.errorType.contains("EndToEndSynchronizationError"),
           context.description.hasPrefix("residualDiff") {
            return "la relecture finale ne correspond pas à l’aperçu confirmé"
        }
        let maximumLength = 500
        guard context.description.count > maximumLength else {
            return "\(context.errorType): \(context.description)"
        }
        return "\(context.errorType): \(context.description.prefix(maximumLength))…"
    }

    private static func restorationTargetDescription(
        _ target: SynchronizationTransactionRestorationTarget
    ) -> String {
        switch target {
        case .targetFile:
            "fichier de favoris"
        case .participant(let participant):
            "état \(participant)"
        }
    }

    private static func makePreview(
        result: SynchronizationPreviewResult,
        safari: SynchronizationSourceSummary,
        chrome: SynchronizationSourceSummary
    ) -> SynchronizationPreviewPresentation {
        let source: SynchronizationSourceSummary
        let target: SynchronizationSourceSummary
        switch result.direction {
        case .safariToChrome:
            source = safari
            target = chrome
        case .chromeToSafari:
            source = chrome
            target = safari
        }

        return SynchronizationPreviewPresentation(
            source: browserSummary(source),
            target: browserSummary(target),
            totalOperationCount: result.totalOperationCount,
            creationCount: result.creationCount,
            deletionCount: result.deletionCount,
            moveCount: result.moveCount,
            renameCount: result.renameCount,
            urlModificationCount: result.urlModificationCount
        )
    }

    private static func browserSummary(
        _ source: SynchronizationSourceSummary
    ) -> SynchronizationBrowserSummary {
        SynchronizationBrowserSummary(
            name: source.source.displayName,
            bookmarkCount: source.bookmarkCount,
            folderCount: source.folderCount
        )
    }
}
