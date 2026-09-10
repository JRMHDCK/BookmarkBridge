//
//  SynchronizationViewModel.swift
//  BookmarkBridge
//

import Foundation
import Observation
import OSLog
#if DEBUG
private let synchronizationViewModelLogger = Logger(
    subsystem: "fr.jerome.BookmarkBridge",
    category: "Synchronization.ViewModel"
)
#endif

private let synchronizationDiagnosticLogger = Logger(
    subsystem: "fr.jerome.BookmarkBridge",
    category: "Diagnostics"
)

/// Read-only boundary used by the UI. The concrete BSE preview service
/// conforms without introducing a UI dependency into Core.
nonisolated protocol SynchronizationPreviewProviding: Sendable {
    func preview(
        request: SynchronizationPreviewRequest
    ) async throws -> SynchronizationPreviewResult
}

extension SynchronizationPreviewService: SynchronizationPreviewProviding {}

nonisolated enum SynchronizationPreviewRequestError:
    Error,
    Equatable,
    Sendable
{
    case readOnlyChromeDestination
}

/// Executes exactly the BSE preview that the user has seen. The concrete app
/// implementation confirms the plan and delegates to
/// `ProductionSynchronizationService`; tests inject a deterministic double.
nonisolated protocol SynchronizationProductionExecuting: Sendable {
    func synchronize(
        preview: SynchronizationPreviewResult
    ) async throws -> SynchronizationProductionExecutionOutcome
}

nonisolated enum SynchronizationProductionExecutionOutcome:
    Hashable,
    Sendable
{
    case synchronized
    case safariImportPrepared(SafariImportPresentation)
}

nonisolated protocol SafariImportPresenting: Sendable {
    @MainActor
    func present(_ importPresentation: SafariImportPresentation)

    @MainActor
    func reveal(_ importPresentation: SafariImportPresentation)

    @MainActor
    func openSafari()
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

nonisolated enum SynchronizationPreviewSectionKind:
    CaseIterable,
    Hashable,
    Sendable
{
    case creation
    case deletion
    case move
    case rename
    case update
}

nonisolated struct SynchronizationPreviewItem:
    Hashable,
    Identifiable,
    Sendable
{
    let id: String
    let section: SynchronizationPreviewSectionKind
    let title: String
    let url: URL?
    let detail: String?
    let isFolder: Bool
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
    let items: [SynchronizationPreviewItem]
    let sections: [SynchronizationPreviewSectionKind]
    let hasUnsupportedChanges: Bool

    func items(
        in section: SynchronizationPreviewSectionKind
    ) -> [SynchronizationPreviewItem] {
        items.filter { $0.section == section }
    }
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
        case awaitingSafariImport(SafariImportPresentation)
        case completed
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var executionState: ExecutionState = .idle
    private(set) var previewDirection: ProductionSynchronizationDirection?
    private(set) var diagnosticContext = DiagnosticContext()
    let selection: SynchronizationSelectionViewModel
    let directionNavigation: SynchronizationDirectionNavigation

    var isSynchronizing: Bool {
        switch executionState {
        case .preparing, .writing, .validating:
            true
        case .idle, .awaitingSafariImport, .completed, .failed:
            false
        }
    }

    var canSynchronize: Bool {
        guard executionService != nil, !isSynchronizing else {
            return false
        }
        if case .awaitingSafariImport = executionState {
            return false
        }
        if case .loaded(let preview) = state {
            return latestPreviewResult != nil && preview.totalOperationCount > 0
        }
        return false
    }

    private let previewService: any SynchronizationPreviewProviding
    private let requestProvider: any SynchronizationPreviewRequestProviding
    private let executionService: (any SynchronizationProductionExecuting)?
    private let safariImportPresenter: (any SafariImportPresenting)?
    private let diagnosticRecorder: (any DiagnosticEventRecording)?
    private let nowProvider: @MainActor @Sendable () -> Date
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
        safariImportPresenter: (any SafariImportPresenting)? = nil,
        preferencesStore: any SynchronizationPreferencesStoring =
            InMemorySynchronizationPreferencesStore(),
        diagnosticRecorder: (any DiagnosticEventRecording)? = nil,
        nowProvider: @escaping @MainActor @Sendable () -> Date = Date.init
    ) {
        self.previewService = previewService
        self.requestProvider = requestProvider
        self.executionService = executionService
        self.safariImportPresenter = safariImportPresenter
        self.diagnosticRecorder = diagnosticRecorder
        self.nowProvider = nowProvider
        selection = SynchronizationSelectionViewModel(
            preferencesStore: preferencesStore
        )
        directionNavigation = SynchronizationDirectionNavigation(
            preferencesStore: preferencesStore
        )
    }

    func reset() {
        #if DEBUG
        if ProcessInfo.processInfo.environment[
            "BOOKMARKBRIDGE_UI_TEST_SYNC_FAILURE"
        ] == "1" {
            showFailureForUITesting()
            return
        }
        #endif
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
        let startedAt = nowProvider()
        await recordDiagnosticEvent(DiagnosticEvent(
            timestamp: startedAt,
            level: .information,
            component: .synchronization,
            stage: .preview,
            outcome: .started,
            direction: Self.diagnosticDirection(direction),
            source: direction == .safariToChrome ? .safariBookmarks : nil,
            counts: Self.sourceCounts(safari: safari, chrome: chrome)
        ))
        #if DEBUG
        synchronizationViewModelLogger.debug(
            "\(PreviewDiagnosticsContext.prefix, privacy: .public) stage=load-preview status=starting safariState=loaded safariFolders=\(safari.folderCount, privacy: .public) safariBookmarks=\(safari.bookmarkCount, privacy: .public) safariSource=\(String(describing: safari.source.id), privacy: .public) chromeState=loaded chromeFolders=\(chrome.folderCount, privacy: .public) chromeBookmarks=\(chrome.bookmarkCount, privacy: .public) chromeProfile=\(chrome.source.id.profile ?? "none", privacy: .public) chromeSource=\(String(describing: chrome.source.id), privacy: .public)"
        )
        #endif
        state = .loading
        latestSources = (safari, chrome)
        var diagnosticSource: DiagnosticSourceCategory? =
            direction == .safariToChrome ? .safariBookmarks : nil
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
            diagnosticSource = Self.diagnosticSource(
                direction: direction,
                request: request
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
            state = preview.totalOperationCount == 0
                ? .empty(preview)
                : .loaded(preview)
            if case .awaitingSafariImport = executionState {
                executionState = result.totalOperationCount == 0
                    ? .completed : .idle
            }
            await recordDiagnosticEvent(DiagnosticEvent(
                timestamp: nowProvider(),
                level: .information,
                component: .synchronization,
                stage: .preview,
                outcome: .succeeded,
                direction: Self.diagnosticDirection(direction),
                source: diagnosticSource,
                durationMilliseconds: durationSince(startedAt),
                counts: DiagnosticCounts(
                    bookmarks: safari.bookmarkCount + chrome.bookmarkCount,
                    folders: safari.folderCount + chrome.folderCount,
                    changes: result.logicalDiff.changes.count
                )
            ))
            #if DEBUG
            synchronizationViewModelLogger.debug(
                "\(PreviewDiagnosticsContext.prefix, privacy: .public) stage=load-preview status=success operations=\(result.totalOperationCount, privacy: .public)"
            )
            #endif
        } catch is CancellationError {
            await recordDiagnosticEvent(DiagnosticEvent(
                timestamp: nowProvider(),
                level: .warning,
                component: .synchronization,
                stage: .preview,
                outcome: .cancelled,
                direction: Self.diagnosticDirection(direction),
                source: diagnosticSource,
                durationMilliseconds: durationSince(startedAt),
                counts: Self.sourceCounts(safari: safari, chrome: chrome)
            ))
            #if DEBUG
            synchronizationViewModelLogger.debug(
                "\(PreviewDiagnosticsContext.prefix, privacy: .public) stage=load-preview status=cancelled replacementActive=\(self.activePreviewAttempts.count > 1, privacy: .public)"
            )
            #endif
            state = .idle
            latestPreviewResult = nil
            previewDirection = nil
        } catch SynchronizationPreviewRequestError
            .readOnlyChromeDestination {
            await recordDiagnosticEvent(DiagnosticEvent(
                timestamp: nowProvider(),
                level: .error,
                component: .synchronization,
                stage: .preview,
                outcome: .failed,
                direction: Self.diagnosticDirection(direction),
                source: diagnosticSource,
                errorType: .unsupportedOperation,
                errorCode: .readOnlyDestination,
                durationMilliseconds: durationSince(startedAt),
                counts: Self.sourceCounts(safari: safari, chrome: chrome)
            ))
            state = .failed(
                DocumentationText.value("legacyPreview.readOnly")
            )
            latestPreviewResult = nil
            previewDirection = nil
        } catch {
            await recordDiagnosticEvent(DiagnosticEvent(
                timestamp: nowProvider(),
                level: .error,
                component: .synchronization,
                stage: .preview,
                outcome: .failed,
                direction: Self.diagnosticDirection(direction),
                source: diagnosticSource,
                errorType: Self.diagnosticErrorType(for: error),
                errorCode: Self.diagnosticErrorCode(for: error),
                durationMilliseconds: durationSince(startedAt),
                counts: Self.sourceCounts(safari: safari, chrome: chrome)
            ))
            #if DEBUG
            synchronizationViewModelLogger.error(
                "\(PreviewDiagnosticsContext.prefix, privacy: .public) stage=load-preview status=failure \(PreviewDiagnosticsContext.errorDescription(error), privacy: .public)"
            )
            #endif
            state = .failed(
                DocumentationText.value("preview.calculationFailed")
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
        guard canSynchronize,
              let executionService,
              let preview = latestPreviewResult,
              let sources = latestSources,
              preview.totalOperationCount > 0 else {
            return false
        }

        executionState = .preparing
        let startedAt = nowProvider()
        await recordDiagnosticEvent(DiagnosticEvent(
            timestamp: startedAt,
            level: .information,
            component: .synchronization,
            stage: .writing,
            outcome: .started,
            direction: Self.diagnosticDirection(preview.direction),
            counts: DiagnosticCounts(changes: preview.totalOperationCount)
        ))
        do {
            executionState = .writing
            let outcome = try await executionService.synchronize(
                preview: preview
            )
            switch outcome {
            case .synchronized:
                executionState = .validating
                await loadPreview(
                    safari: sources.safari,
                    chrome: sources.chrome,
                    direction: preview.direction
                )
                executionState = .completed
                await recordDiagnosticEvent(DiagnosticEvent(
                    timestamp: nowProvider(),
                    level: .information,
                    component: .synchronization,
                    stage: .validation,
                    outcome: .succeeded,
                    direction: Self.diagnosticDirection(preview.direction),
                    durationMilliseconds: durationSince(startedAt),
                    counts: DiagnosticCounts(
                        changes: preview.totalOperationCount
                    )
                ))
                return true
            case .safariImportPrepared(let importPresentation):
                executionState = .awaitingSafariImport(
                    importPresentation
                )
                safariImportPresenter?.present(importPresentation)
                await recordDiagnosticEvent(DiagnosticEvent(
                    timestamp: nowProvider(),
                    level: .information,
                    component: .synchronization,
                    stage: .importPreparation,
                    outcome: .succeeded,
                    direction: .chromeToSafari,
                    durationMilliseconds: durationSince(startedAt),
                    counts: DiagnosticCounts(
                        bookmarks: importPresentation.bookmarkCount,
                        folders: importPresentation.folderCount,
                        changes: preview.totalOperationCount
                    )
                ))
                return false
            }
        } catch is CancellationError {
            await recordDiagnosticEvent(DiagnosticEvent(
                timestamp: nowProvider(),
                level: .warning,
                component: .synchronization,
                stage: .writing,
                outcome: .cancelled,
                direction: Self.diagnosticDirection(preview.direction),
                durationMilliseconds: durationSince(startedAt),
                counts: DiagnosticCounts(
                    changes: preview.totalOperationCount
                )
            ))
            executionState = .failed(
                DocumentationText.value("sync.cancelled")
            )
            return false
        } catch {
            await recordDiagnosticEvent(DiagnosticEvent(
                timestamp: nowProvider(),
                level: .error,
                component: .synchronization,
                stage: Self.diagnosticStage(for: error),
                outcome: .failed,
                direction: Self.diagnosticDirection(preview.direction),
                errorType: Self.diagnosticErrorType(for: error),
                errorCode: Self.diagnosticErrorCode(for: error),
                durationMilliseconds: durationSince(startedAt),
                counts: DiagnosticCounts(
                    changes: preview.totalOperationCount
                )
            ))
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

    func revealPreparedSafariImport() {
        guard case .awaitingSafariImport(let importPresentation) =
                executionState else { return }
        safariImportPresenter?.reveal(importPresentation)
    }

    func openSafariForPreparedImport() {
        guard case .awaitingSafariImport = executionState else { return }
        safariImportPresenter?.openSafari()
    }

    private func recordDiagnosticEvent(_ event: DiagnosticEvent) async {
        diagnosticContext = DiagnosticContext(
            direction: event.direction,
            stage: event.stage,
            errorType: event.errorType,
            errorCode: event.errorCode,
            durationMilliseconds: event.durationMilliseconds,
            counts: event.counts
        )
        guard let diagnosticRecorder else { return }
        do {
            try await diagnosticRecorder.record(event, now: event.timestamp)
        } catch {
            synchronizationDiagnosticLogger.error(
                "Diagnostic event persistence failed"
            )
        }
    }

    private func durationSince(_ start: Date) -> UInt64? {
        let milliseconds = nowProvider().timeIntervalSince(start) * 1_000
        guard milliseconds.isFinite else { return nil }
        return UInt64(min(max(0, milliseconds), Double(Int.max)))
    }

    private static func sourceCounts(
        safari: SynchronizationSourceSummary,
        chrome: SynchronizationSourceSummary
    ) -> DiagnosticCounts {
        DiagnosticCounts(
            bookmarks: safari.bookmarkCount + chrome.bookmarkCount,
            folders: safari.folderCount + chrome.folderCount
        )
    }

    private static func diagnosticDirection(
        _ direction: ProductionSynchronizationDirection
    ) -> DiagnosticSynchronizationDirection {
        switch direction {
        case .safariToChrome:
            return .safariToChrome
        case .chromeToSafari:
            return .chromeToSafari
        }
    }

    private static func diagnosticSource(
        direction: ProductionSynchronizationDirection,
        request: SynchronizationPreviewRequest
    ) -> DiagnosticSourceCategory {
        if direction == .safariToChrome {
            return .safariBookmarks
        }
        return request.chromeBookmarksURL.lastPathComponent
            == "AccountBookmarks"
            ? .chromeAccount
            : .chromeLocal
    }

    private static func diagnosticStage(for error: any Error) -> DiagnosticStage {
        if error is SafariImportWorkflowError
                || error is SafariImportPackageError {
            return .importPreparation
        }
        guard let transactionError = error as? SynchronizationTransactionError else {
            return .writing
        }
        switch transactionError {
        case .backupCreationFailed, .participantCaptureFailed:
            return .backup
        case .executionFailed:
            return .writing
        case .finalValidationFailed:
            return .validation
        case .restorationFailed:
            return .restoration
        }
    }

    private static func diagnosticErrorCode(
        for error: any Error
    ) -> DiagnosticErrorCode {
        if let importError = error as? SafariImportWorkflowError {
            switch importError {
            case .invalidDirection, .noImportableChanges,
                    .destinationRequired:
                return .unknown
            }
        }
        if let bookmarkError = error as? BookmarkError {
            switch bookmarkError {
            case .sourceNotFound:
                return .sourceNotFound
            case .accessDenied:
                return .accessDenied
            case .authorizationRequired:
                return .authorizationRequired
            case .decodingFailed:
                return .decodingFailed
            case .unsupportedBrowser:
                return .unsupportedBrowser
            case .multipleBookmarkStores:
                return .multipleBookmarkStores
            case .unknownNode:
                return .unknown
            }
        }
        guard let transactionError = error as? SynchronizationTransactionError else {
            return .unknown
        }
        switch transactionError {
        case .backupCreationFailed, .participantCaptureFailed:
            return .backupFailed
        case .executionFailed:
            return .transactionFailed
        case .finalValidationFailed:
            return .validationFailed
        case .restorationFailed:
            return .restorationFailed
        }
    }

    private static func diagnosticErrorType(
        for error: any Error
    ) -> DiagnosticErrorType {
        if let importError = error as? SafariImportWorkflowError {
            switch importError {
            case .invalidDirection, .noImportableChanges,
                    .destinationRequired:
                return .unsupportedOperation
            }
        }
        if error is SafariImportPackageError {
            return .writing
        }
        if let bookmarkError = error as? BookmarkError {
            switch bookmarkError {
            case .accessDenied, .authorizationRequired:
                return .authorization
            case .sourceNotFound:
                return .reading
            case .decodingFailed:
                return .decoding
            case .unsupportedBrowser, .multipleBookmarkStores:
                return .unsupportedOperation
            case .unknownNode:
                return .unknown
            }
        }
        guard let transactionError = error as? SynchronizationTransactionError else {
            return .unknown
        }
        switch transactionError {
        case .backupCreationFailed, .participantCaptureFailed:
            return .backup
        case .executionFailed:
            return .writing
        case .finalValidationFailed:
            return .validation
        case .restorationFailed:
            return .restoration
        }
    }

    private static func executionFailureDescription(
        _ error: any Error
    ) -> String {
        if error is SafariImportWorkflowError {
            return DocumentationText.value("safariImport.failure.generic")
        }
        if error is SafariImportPackageError {
            return DocumentationText.value("safariImport.failure.generic")
        }
        guard let transactionError = error as? SynchronizationTransactionError
        else {
            return DocumentationText.formatted(
                "sync.failure.generic",
                String(reflecting: type(of: error)),
                String(describing: error)
            )
        }
        switch transactionError {
        case .finalValidationFailed(let failure):
            return DocumentationText.formatted(
                "sync.failure.finalValidation",
                conciseCause(failure.cause)
            )
        case .restorationFailed(let failure):
            let restorationFailures = failure.restorationFailures.map {
                "\(restorationTargetDescription($0.target)) : "
                    + conciseCause($0.context)
            }.joined(separator: " ; ")
            let details = restorationFailures.isEmpty
                ? DocumentationText.value("sync.failure.noRestoreDetails")
                : DocumentationText.formatted(
                    "sync.failure.restoreDetails",
                    restorationFailures
                )
            return DocumentationText.formatted(
                "sync.failure.restoration",
                failure.appliedOperationCount,
                conciseCause(failure.cause),
                details
            )
        case .executionFailed(let failure):
            return DocumentationText.formatted(
                "sync.failure.execution",
                conciseCause(failure.cause)
            )
        case .backupCreationFailed(let context):
            return DocumentationText.formatted(
                "sync.failure.backup",
                conciseCause(context)
            )
        case .participantCaptureFailed(let participant, let context):
            return DocumentationText.formatted(
                "sync.failure.capture",
                String(describing: participant),
                conciseCause(context)
            )
        }
    }

    private static func conciseCause(
        _ context: SynchronizationTransactionFailureContext
    ) -> String {
        if context.errorType.contains("EndToEndSynchronizationError"),
           context.description.hasPrefix("residualDiff") {
            return DocumentationText.value("sync.failure.residualCause")
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
            DocumentationText.value("sync.restoreTarget.bookmarksFile")
        case .participant(let participant):
            DocumentationText.formatted(
                "sync.restoreTarget.participant",
                String(describing: participant)
            )
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

        let analyzer = SafariImportCompatibilityAnalyzer()
        let items: [SynchronizationPreviewItem] = zip(
            result.plan.operations, result.changeDetails
        ).enumerated().compactMap { index, pair in
            let (operation, detail) = pair
            guard result.direction != .chromeToSafari
                    || analyzer.supports(operation) else { return nil }
            return previewItem(detail, index: index)
        }
        return SynchronizationPreviewPresentation(
            source: browserSummary(source),
            target: browserSummary(target),
            totalOperationCount: items.count,
            creationCount: items.count { $0.section == .creation },
            deletionCount: items.count { $0.section == .deletion },
            moveCount: items.count { $0.section == .move },
            renameCount: items.count { $0.section == .rename },
            urlModificationCount: items.count { $0.section == .update },
            items: items,
            sections: result.direction == .chromeToSafari
                ? [.creation] : SynchronizationPreviewSectionKind.allCases,
            hasUnsupportedChanges: items.count < result.totalOperationCount
        )
    }

    private static func previewItem(
        _ detail: SynchronizationPreviewChangeDetail,
        index: Int
    ) -> SynchronizationPreviewItem {
        let title = detail.title.isEmpty
            ? DocumentationText.value("bookmark.untitled")
            : detail.title
        let section: SynchronizationPreviewSectionKind
        let secondaryDetail: String?
        switch detail.kind {
        case .creation:
            section = .creation
            secondaryDetail = nil
        case .deletion:
            section = .deletion
            secondaryDetail = nil
        case .move:
            section = .move
            secondaryDetail = detail.destinationTitle.map { "→ \($0)" }
        case .rename:
            section = .rename
            secondaryDetail = detail.previousTitle.flatMap {
                $0 == title ? nil : "\($0) → \(title)"
            }
        case .update:
            section = .update
            secondaryDetail = detail.previousURL.flatMap { previousURL in
                guard previousURL != detail.url else { return nil }
                return "\(previousURL.absoluteString) → "
                    + (detail.url?.absoluteString ?? "")
            }
        }
        return SynchronizationPreviewItem(
            id: "\(detail.logicalNodeID.description)-\(index)",
            section: section,
            title: title,
            url: detail.url,
            detail: secondaryDetail,
            isFolder: detail.isFolder
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

    #if DEBUG
    func showFailureForUITesting() {
        state = .failed(
            DocumentationText.value("preview.calculationFailed")
        )
        diagnosticContext = DiagnosticContext(
            direction: .chromeToSafari,
            stage: .preview,
            errorType: .synchronization,
            errorCode: .previewFailed
        )
    }
    #endif
}
