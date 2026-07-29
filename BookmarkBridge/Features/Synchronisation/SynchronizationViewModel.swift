//
//  SynchronizationViewModel.swift
//  BookmarkBridge
//

import Foundation
import Observation

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
        chromeSource: BookmarkSource
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

    init(
        previewService: any SynchronizationPreviewProviding,
        requestProvider: any SynchronizationPreviewRequestProviding,
        executionService:
            (any SynchronizationProductionExecuting)? = nil
    ) {
        self.previewService = previewService
        self.requestProvider = requestProvider
        self.executionService = executionService
    }

    func reset() {
        state = .idle
        executionState = .idle
        latestPreviewResult = nil
        latestSources = nil
    }

    func loadPreview(
        safari: SynchronizationSourceSummary,
        chrome: SynchronizationSourceSummary
    ) async {
        state = .loading
        latestSources = (safari, chrome)
        do {
            let request = try await requestProvider.makeRequest(
                safariSource: safari.source,
                chromeSource: chrome.source
            )
            let result = try await previewService.preview(request: request)
            latestPreviewResult = result
            let preview = Self.makePreview(
                result: result,
                safari: safari,
                chrome: chrome
            )
            state = result.totalOperationCount == 0
                ? .empty(preview)
                : .loaded(preview)
        } catch is CancellationError {
            state = .idle
            latestPreviewResult = nil
        } catch {
            state = .failed(
                "Impossible de calculer la prévisualisation."
            )
            latestPreviewResult = nil
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
                chrome: sources.chrome
            )
            executionState = .completed
            return true
        } catch is CancellationError {
            executionState = .failed(
                "La synchronisation a été annulée."
            )
            return false
        } catch {
            executionState = .failed(
                "La synchronisation a échoué. Aucune modification partielle n'a été conservée."
            )
            return false
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
