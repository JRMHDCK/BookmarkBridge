//
//  SynchronizationViewModelTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("SynchronizationViewModel")
@MainActor
struct SynchronizationViewModelTests {
    @Test("Starts idle")
    func idle() throws {
        let result = try makeResult(operations: [])
        let viewModel = makeViewModel(
            service: PreviewServiceDouble(result: result)
        )

        #expect(viewModel.state == .idle)
    }

    @Test("Exposes loading while preview is suspended")
    func loading() async throws {
        let result = try makeResult(operations: [])
        let service = SuspendedPreviewService()
        let viewModel = makeViewModel(service: service)

        let task = Task {
            await viewModel.loadPreview(
                safari: safariSummary,
                chrome: chromeSummary
            )
        }
        while !(await service.hasStarted) {
            await Task.yield()
        }

        #expect(viewModel.state == .loading)

        await service.complete(with: result)
        await task.value
        guard case .empty = viewModel.state else {
            Issue.record("Expected the completed empty preview")
            return
        }
    }

    @Test("Maps BSE operation counts and source summaries to loaded UI data")
    func loaded() async throws {
        let operations = [
            SynchronizationOperation.create(CreateNodeOperation(
                logicalNodeID: logicalID(1),
                kind: .folder,
                title: "Created",
                url: nil,
                parentID: nil,
                position: 0
            )),
            .delete(DeleteNodeOperation(logicalNodeID: logicalID(2))),
            .move(MoveNodeOperation(
                logicalNodeID: logicalID(3),
                parentID: logicalID(1),
                position: 0
            )),
            .rename(RenameNodeOperation(
                logicalNodeID: logicalID(4),
                title: "Renamed"
            )),
            .updateURL(UpdateURLOperation(
                logicalNodeID: logicalID(5),
                url: URL(string: "https://example.com/new")!
            )),
        ]
        let result = try makeResult(operations: operations)
        let viewModel = makeViewModel(
            service: PreviewServiceDouble(result: result)
        )

        await viewModel.loadPreview(
            safari: safariSummary,
            chrome: chromeSummary
        )

        guard case .loaded(let preview) = viewModel.state else {
            Issue.record("Expected a loaded preview")
            return
        }
        #expect(preview.source.name == "Safari")
        #expect(preview.source.bookmarkCount == 12)
        #expect(preview.source.folderCount == 3)
        #expect(preview.target.name == "Chrome — Default")
        #expect(preview.target.bookmarkCount == 8)
        #expect(preview.target.folderCount == 2)
        #expect(preview.totalOperationCount == 5)
        #expect(preview.creationCount == 1)
        #expect(preview.deletionCount == 1)
        #expect(preview.moveCount == 1)
        #expect(preview.renameCount == 1)
        #expect(preview.urlModificationCount == 1)
    }

    @Test("Maps a zero-operation preview to empty")
    func empty() async throws {
        let result = try makeResult(operations: [])
        let viewModel = makeViewModel(
            service: PreviewServiceDouble(result: result)
        )

        await viewModel.loadPreview(
            safari: safariSummary,
            chrome: chromeSummary
        )

        guard case .empty(let preview) = viewModel.state else {
            Issue.record("Expected an empty preview")
            return
        }
        #expect(preview.totalOperationCount == 0)
        #expect(preview.source.name == "Safari")
        #expect(preview.target.name == "Chrome — Default")
    }

    @Test("Reset clears a previously loaded preview")
    func reset() async throws {
        let result = try makeResult(operations: [
            .delete(DeleteNodeOperation(logicalNodeID: logicalID(1))),
        ])
        let viewModel = makeViewModel(
            service: PreviewServiceDouble(result: result)
        )
        await viewModel.loadPreview(
            safari: safariSummary,
            chrome: chromeSummary
        )
        guard case .loaded = viewModel.state else {
            Issue.record("Expected a loaded preview before reset")
            return
        }

        viewModel.reset()

        #expect(viewModel.state == .idle)
    }

    @Test("Maps preview errors to failed without retaining loading")
    func failed() async {
        let viewModel = makeViewModel(
            service: PreviewServiceDouble(error: TestFailure.preview)
        )

        await viewModel.loadPreview(
            safari: safariSummary,
            chrome: chromeSummary
        )

        #expect(
            viewModel.state
                == .failed("Impossible de calculer la prévisualisation.")
        )
    }

    @Test("Cancellation returns to idle")
    func cancellation() async {
        let viewModel = makeViewModel(
            service: PreviewServiceDouble(error: CancellationError())
        )

        await viewModel.loadPreview(
            safari: safariSummary,
            chrome: chromeSummary
        )

        #expect(viewModel.state == .idle)
    }

    @Test("Production preview request preserves authorized roots and stable source IDs")
    func productionRequestUsesAuthorizedRoots() async throws {
        let safariURL = URL(
            fileURLWithPath:
                "/tmp/BookmarkBridgeTests/Library/Safari/Bookmarks.plist"
        )
        let chromeDirectoryURL = URL(
            fileURLWithPath:
                "/tmp/BookmarkBridgeTests/Library/Application Support/Google/Chrome"
        )
        let provider = DashboardSynchronizationPreviewRequestProvider(
            safariLocator: StubBookmarkSourceLocator(
                result: .success(
                    BrowserLocation(
                        browser: .safari,
                        fileURL: safariURL
                    )
                )
            ),
            chromeLocator: StubBookmarkSourceLocator(
                result: .success(
                    BrowserLocation(
                        browser: .chrome,
                        fileURL: chromeDirectoryURL
                    )
                )
            )
        )
        let safariSource = BookmarkSource.singleProfile(.safari)
        let chromeSource = BookmarkSource(
            browser: .chrome,
            profile: "Default",
            displayName: "Chrome"
        )

        let first = try await provider.makeRequest(
            safariSource: safariSource,
            chromeSource: chromeSource
        )
        let second = try await provider.makeRequest(
            safariSource: safariSource,
            chromeSource: chromeSource
        )

        #expect(first.safariSecurityScopeURL == safariURL)
        #expect(first.chromeSecurityScopeURL == chromeDirectoryURL)
        #expect(
            first.chromeBookmarksURL
                == chromeDirectoryURL
                    .appendingPathComponent("Default/Bookmarks")
        )
        #expect(first.safariSourceID == second.safariSourceID)
        #expect(first.chromeSourceID == second.chromeSourceID)
    }

    @Test("A successful synchronization automatically refreshes the preview")
    func synchronizationSuccessRefreshesPreview() async throws {
        let initial = try makeResult(operations: [
            .delete(DeleteNodeOperation(logicalNodeID: logicalID(1))),
        ])
        let synchronized = try makeResult(operations: [])
        let previewService = SequencedPreviewService([
            initial,
            synchronized,
        ])
        let executionService = ExecutionServiceDouble()
        let viewModel = makeViewModel(
            service: previewService,
            executionService: executionService
        )
        await viewModel.loadPreview(
            safari: safariSummary,
            chrome: chromeSummary
        )

        let succeeded = await viewModel.synchronize()

        #expect(succeeded)
        #expect(viewModel.executionState == .completed)
        guard case .empty(let preview) = viewModel.state else {
            Issue.record("Expected the automatically refreshed empty preview")
            return
        }
        #expect(preview.totalOperationCount == 0)
        #expect(await previewService.callCount == 2)
        #expect(await executionService.callCount == 1)
    }

    @Test("A failed synchronization keeps the last valid preview for retry")
    func synchronizationFailurePreservesPreview() async throws {
        let initial = try makeResult(operations: [
            .rename(RenameNodeOperation(
                logicalNodeID: logicalID(1),
                title: "Renamed"
            )),
        ])
        let executionService = ExecutionServiceDouble(
            error: TestFailure.execution
        )
        let viewModel = makeViewModel(
            service: PreviewServiceDouble(result: initial),
            executionService: executionService
        )
        await viewModel.loadPreview(
            safari: safariSummary,
            chrome: chromeSummary
        )

        let succeeded = await viewModel.synchronize()

        #expect(!succeeded)
        guard case .loaded(let preview) = viewModel.state else {
            Issue.record("Expected the last valid preview to remain visible")
            return
        }
        #expect(preview.renameCount == 1)
        guard case .failed(let message) = viewModel.executionState else {
            Issue.record("Expected a user-facing execution failure")
            return
        }
        #expect(message.contains("TestFailure"))
        #expect(message.contains("execution"))
        #expect(viewModel.canSynchronize)
    }

    @Test("A second click is ignored while synchronization is suspended")
    func doubleClickIsIgnored() async throws {
        let initial = try makeResult(operations: [
            .delete(DeleteNodeOperation(logicalNodeID: logicalID(1))),
        ])
        let executionService = SuspendedExecutionService()
        let viewModel = makeViewModel(
            service: PreviewServiceDouble(result: initial),
            executionService: executionService
        )
        await viewModel.loadPreview(
            safari: safariSummary,
            chrome: chromeSummary
        )

        let first = Task { await viewModel.synchronize() }
        while !(await executionService.hasStarted) {
            await Task.yield()
        }

        #expect(viewModel.isSynchronizing)
        #expect(!viewModel.canSynchronize)
        let secondResult = await viewModel.synchronize()
        #expect(!secondResult)
        #expect(await executionService.callCount == 1)

        await executionService.complete()
        #expect(await first.value)
        #expect(await executionService.callCount == 1)
    }

    @Test("An empty preview cannot be synchronized")
    func alreadySynchronizedIsDisabled() async throws {
        let empty = try makeResult(operations: [])
        let executionService = ExecutionServiceDouble()
        let viewModel = makeViewModel(
            service: PreviewServiceDouble(result: empty),
            executionService: executionService
        )

        await viewModel.loadPreview(
            safari: safariSummary,
            chrome: chromeSummary
        )

        #expect(!viewModel.canSynchronize)
        let synchronized = await viewModel.synchronize()
        #expect(!synchronized)
        #expect(await executionService.callCount == 0)
    }

    private var safariSummary: SynchronizationSourceSummary {
        SynchronizationSourceSummary(
            source: .singleProfile(.safari),
            summary: BrowserBookmarkSummary(
                browser: .safari,
                folderCount: 3,
                bookmarkCount: 12,
                nodeCount: 15,
                capturedAt: .distantPast
            )
        )
    }

    private var chromeSummary: SynchronizationSourceSummary {
        SynchronizationSourceSummary(
            source: BookmarkSource(
                browser: .chrome,
                profile: "Default",
                displayName: "Chrome — Default"
            ),
            summary: BrowserBookmarkSummary(
                browser: .chrome,
                folderCount: 2,
                bookmarkCount: 8,
                nodeCount: 10,
                capturedAt: .distantPast
            )
        )
    }

    private func makeViewModel(
        service: any SynchronizationPreviewProviding,
        executionService:
            (any SynchronizationProductionExecuting)? = nil
    ) -> SynchronizationViewModel {
        SynchronizationViewModel(
            previewService: service,
            requestProvider: PreviewRequestProviderDouble(),
            executionService: executionService
        )
    }

    private func makeResult(
        operations: [SynchronizationOperation]
    ) throws -> SynchronizationPreviewResult {
        let safariSourceID = sourceID(1)
        let chromeSourceID = sourceID(2)
        let direction = SynchronizationDirection.oneWay(
            source: safariSourceID,
            target: chromeSourceID
        )
        let policy = SynchronizationPolicy.allChanges(direction: direction)
        let plan = SynchronizationPlan(
            phases: [
                .preparation(operations.filter {
                    if case .create = $0 { true } else { false }
                }),
                .structural(operations.filter {
                    if case .move = $0 { true } else { false }
                }),
                .content(operations.filter {
                    switch $0 {
                    case .rename, .updateURL: true
                    default: false
                    }
                }),
                .cleanup(operations.filter {
                    if case .delete = $0 { true } else { false }
                }),
            ],
            report: SynchronizationPlanningReport(
                policy: policy,
                inputChangeCount: operations.count,
                plannedOperationCount: operations.count,
                skippedChangeCount: 0,
                preparationOperationCount: operations.count {
                    if case .create = $0 { true } else { false }
                },
                structuralOperationCount: operations.count {
                    if case .move = $0 { true } else { false }
                },
                contentOperationCount: operations.count {
                    switch $0 {
                    case .rename, .updateURL: true
                    default: false
                    }
                },
                cleanupOperationCount: operations.count {
                    if case .delete = $0 { true } else { false }
                }
            )
        )
        let tree = try BSETree(nodes: [])
        let request = SynchronizationPreviewRequest(
            direction: .safariToChrome,
            safariSourceID: safariSourceID,
            chromeSourceID: chromeSourceID,
            safariBookmarksURL: URL(fileURLWithPath: "/tmp/Safari.plist"),
            chromeBookmarksURL: URL(fileURLWithPath: "/tmp/Bookmarks"),
            chromeProfileIdentifier: try ChromeProfileIdentifier("Default")
        )
        return try SynchronizationPreviewResult(
            request: request,
            sourceSnapshot: BSESnapshot(
                source: safariSourceID,
                capturedAt: .distantPast,
                tree: tree
            ),
            targetSnapshot: BSESnapshot(
                source: chromeSourceID,
                capturedAt: .distantPast,
                tree: tree
            ),
            logicalDiff: LogicalDiffResult(
                changes: [],
                report: LogicalDiffReport(
                    beforeNodeCount: 0,
                    afterNodeCount: 0,
                    unchangedNodeCount: 0,
                    createdCount: 0,
                    deletedCount: 0,
                    renamedCount: 0,
                    urlChangedCount: 0,
                    movedCount: 0,
                    reorderedCount: 0,
                    lifecycleChangedCount: 0
                )
            ),
            plan: plan
        )
    }

    private func sourceID(_ value: UInt8) -> BSESourceID {
        BSESourceID(UUID(uuid: (
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, value
        )))
    }

    private func logicalID(_ value: UInt8) -> LogicalNodeID {
        LogicalNodeID(UUID(uuid: (
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, value
        )))
    }
}

nonisolated private enum TestFailure: Error, Sendable {
    case preview
    case execution
}

nonisolated private struct PreviewRequestProviderDouble:
    SynchronizationPreviewRequestProviding
{
    func makeRequest(
        safariSource: BookmarkSource,
        chromeSource: BookmarkSource
    ) async throws -> SynchronizationPreviewRequest {
        SynchronizationPreviewRequest(
            direction: .safariToChrome,
            safariSourceID: BSESourceID(UUID(uuid: (
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 1
            ))),
            chromeSourceID: BSESourceID(UUID(uuid: (
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 2
            ))),
            safariBookmarksURL: URL(fileURLWithPath: "/tmp/Safari.plist"),
            chromeBookmarksURL: URL(fileURLWithPath: "/tmp/Bookmarks"),
            chromeProfileIdentifier: try ChromeProfileIdentifier(
                chromeSource.id.profile ?? "Default"
            )
        )
    }
}

nonisolated private struct PreviewServiceDouble:
    SynchronizationPreviewProviding
{
    let result: SynchronizationPreviewResult?
    let error: (any Error & Sendable)?

    init(result: SynchronizationPreviewResult) {
        self.result = result
        error = nil
    }

    init(error: any Error & Sendable) {
        result = nil
        self.error = error
    }

    func preview(
        request: SynchronizationPreviewRequest
    ) async throws -> SynchronizationPreviewResult {
        if let error { throw error }
        return try #require(result)
    }
}

private actor SuspendedPreviewService: SynchronizationPreviewProviding {
    private var continuation:
        CheckedContinuation<SynchronizationPreviewResult, any Error>?
    private(set) var hasStarted = false

    func preview(
        request: SynchronizationPreviewRequest
    ) async throws -> SynchronizationPreviewResult {
        hasStarted = true
        return try await withCheckedThrowingContinuation {
            continuation = $0
        }
    }

    func complete(with result: SynchronizationPreviewResult) {
        continuation?.resume(returning: result)
        continuation = nil
    }
}

private actor SequencedPreviewService: SynchronizationPreviewProviding {
    private var results: [SynchronizationPreviewResult]
    private(set) var callCount = 0

    init(_ results: [SynchronizationPreviewResult]) {
        self.results = results
    }

    func preview(
        request: SynchronizationPreviewRequest
    ) async throws -> SynchronizationPreviewResult {
        callCount += 1
        guard !results.isEmpty else {
            throw TestFailure.preview
        }
        return results.removeFirst()
    }
}

private actor ExecutionServiceDouble: SynchronizationProductionExecuting {
    private let error: TestFailure?
    private(set) var callCount = 0

    init(error: TestFailure? = nil) {
        self.error = error
    }

    func synchronize(
        preview: SynchronizationPreviewResult
    ) async throws {
        callCount += 1
        if let error {
            throw error
        }
    }
}

private actor SuspendedExecutionService:
    SynchronizationProductionExecuting
{
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var hasStarted = false
    private(set) var callCount = 0

    func synchronize(
        preview: SynchronizationPreviewResult
    ) async throws {
        hasStarted = true
        callCount += 1
        await withCheckedContinuation {
            continuation = $0
        }
    }

    func complete() {
        continuation?.resume()
        continuation = nil
    }
}
