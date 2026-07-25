//
//  SynchronizationPreviewServiceTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Synchronization
import Testing
@testable import BookmarkBridge

@Suite("BSE-780 Synchronization Preview")
struct SynchronizationPreviewServiceTests {
    @Test(
        "Preview reports each supported change without touching browser files",
        arguments: PreviewScenario.allCases
    )
    private func previewsScenario(_ scenario: PreviewScenario) async throws {
        let fixture = try await PreviewFixture.make(scenario: scenario)
        defer { fixture.remove() }

        let result = try await fixture.service.preview(request: fixture.request)

        #expect(result.direction == scenario.direction)
        #expect(
            result.plan.phases.flatMap(\.operations).map(previewOperationKind)
                == scenario.expectedOperationKinds
        )
        #expect(result.totalOperationCount == scenario.expectedOperationKinds.count)
        #expect(
            result.creationCount
                == scenario.expectedOperationKinds.count { $0 == .create }
        )
        #expect(
            result.deletionCount
                == scenario.expectedOperationKinds.count { $0 == .delete }
        )
        #expect(
            result.renameCount
                == scenario.expectedOperationKinds.count { $0 == .rename }
        )
        #expect(
            result.moveCount
                == scenario.expectedOperationKinds.count { $0 == .move }
        )
        #expect(
            result.urlModificationCount
                == scenario.expectedOperationKinds.count { $0 == .updateURL }
        )
        try fixture.expectNoFileSystemMutation()
    }

    @Test("Identical inputs produce an identical preview")
    func previewIsDeterministic() async throws {
        let fixture = try await PreviewFixture.make(scenario: .combined)
        defer { fixture.remove() }

        let first = try await fixture.service.preview(request: fixture.request)
        let second = try await fixture.service.preview(request: fixture.request)

        #expect(first == second)
        try fixture.expectNoFileSystemMutation()
    }

    @Test(
        "Each shared-pipeline failure keeps its public preview category",
        arguments: PreviewPipelineFailureScenario.allCases
    )
    private func mapsPipelineFailure(
        _ scenario: PreviewPipelineFailureScenario
    ) async throws {
        let pipeline = PreviewPipelineDouble(error: scenario.pipelineError)
        let service = SynchronizationPreviewService(pipeline: pipeline)
        let request = try previewSeamRequest()

        let first = await capturedPreviewError {
            try await service.preview(request: request)
        }

        #expect(scenario.matches(first))
        #expect(pipeline.executeCount == 1)
        #expect(pipeline.analyzeCount == 0)

        let secondPipeline = PreviewPipelineDouble(
            error: scenario.pipelineError
        )
        let secondService = SynchronizationPreviewService(
            pipeline: secondPipeline
        )
        let second = await capturedPreviewError {
            try await secondService.preview(request: request)
        }

        #expect(first == second)
        #expect(secondPipeline.executeCount == 1)
        #expect(secondPipeline.analyzeCount == 0)
    }

    @Test("The injectable pipeline boundary is Sendable")
    func pipelineBoundaryIsSendable() async throws {
        let pipeline = PreviewPipelineDouble(
            error: PreviewPipelineFailureScenario.matching.pipelineError
        )
        let service = SynchronizationPreviewService(pipeline: pipeline)
        let request = try previewSeamRequest()

        let error = await Task.detached {
            await capturedPreviewError {
                try await service.preview(request: request)
            }
        }.value

        #expect(PreviewPipelineFailureScenario.matching.matches(error))
    }
}

private enum PreviewPipelineFailureScenario:
    String,
    CaseIterable,
    CustomTestStringConvertible,
    Sendable
{
    case sourceRead
    case targetRead
    case matching
    case bootstrap
    case projection
    case diff
    case planning

    var testDescription: String { rawValue }

    var pipelineError: SynchronizationPipelineError {
        let context = SynchronizationPipelineFailureContext(
            PreviewPipelineTestFailure.injected
        )
        return switch self {
        case .sourceRead: .sourceReadFailure(context)
        case .targetRead: .targetReadFailure(context)
        case .matching: .matchingFailure(context)
        case .bootstrap: .bootstrapFailure(context)
        case .projection: .projectionFailure(context)
        case .diff: .diffFailure(context)
        case .planning: .planningFailure(context)
        }
    }

    func matches(_ error: SynchronizationPreviewError?) -> Bool {
        switch (self, error) {
        case (.sourceRead, .sourceReadFailure),
            (.targetRead, .targetReadFailure),
            (.matching, .matchingFailure),
            (.bootstrap, .bootstrapFailure),
            (.projection, .projectionFailure),
            (.diff, .diffFailure),
            (.planning, .planningFailure):
            true
        default:
            false
        }
    }
}

private final class PreviewPipelineDouble:
    SynchronizationPipelineExecuting,
    Sendable
{
    private struct State: Sendable {
        var executeCount = 0
        var analyzeCount = 0
    }

    private let error: SynchronizationPipelineError
    private let state = Mutex(State())

    init(error: SynchronizationPipelineError) {
        self.error = error
    }

    var executeCount: Int {
        state.withLock { $0.executeCount }
    }

    var analyzeCount: Int {
        state.withLock { $0.analyzeCount }
    }

    func execute(
        request: SynchronizationPipelineRequest
    ) async throws -> SynchronizationPipelineResult {
        state.withLock { $0.executeCount += 1 }
        throw error
    }

    func analyze(
        request: SynchronizationPipelineRequest
    ) async throws -> SynchronizationPipelineAnalysis {
        state.withLock { $0.analyzeCount += 1 }
        throw error
    }
}

private enum PreviewPipelineTestFailure: Error {
    case injected
}

private func capturedPreviewError(
    _ operation: () async throws -> SynchronizationPreviewResult
) async -> SynchronizationPreviewError? {
    do {
        _ = try await operation()
        Issue.record("Expected preview to fail")
        return nil
    } catch let error as SynchronizationPreviewError {
        return error
    } catch {
        Issue.record("Unexpected error: \(error)")
        return nil
    }
}

private func previewSeamRequest() throws -> SynchronizationPreviewRequest {
    SynchronizationPreviewRequest(
        direction: .safariToChrome,
        safariSourceID: BSESourceID(previewUUID(91)),
        chromeSourceID: BSESourceID(previewUUID(92)),
        safariBookmarksURL: URL(fileURLWithPath: "/tmp/bse796a-safari"),
        chromeBookmarksURL: URL(fileURLWithPath: "/tmp/bse796a-chrome"),
        chromeProfileIdentifier: try ChromeProfileIdentifier("Default")
    )
}

private enum PreviewOperationKind: Hashable, Sendable {
    case create
    case delete
    case rename
    case updateURL
    case move
    case reorder
    case archive
}

private func previewOperationKind(
    _ operation: SynchronizationOperation
) -> PreviewOperationKind {
    switch operation {
    case .create: .create
    case .delete: .delete
    case .rename: .rename
    case .updateURL: .updateURL
    case .move: .move
    case .reorder: .reorder
    case .archive: .archive
    }
}

private enum PreviewScenario: String, CaseIterable, Sendable {
    case noChange
    case creation
    case reverseCreation
    case rename
    case move
    case updateURL
    case deletion
    case combined

    var direction: ProductionSynchronizationDirection {
        self == .reverseCreation ? .chromeToSafari : .safariToChrome
    }

    var expectedOperationKinds: [PreviewOperationKind] {
        switch self {
        case .noChange:
            []
        case .creation, .reverseCreation:
            [.create]
        case .rename:
            [.rename]
        case .move:
            [.move]
        case .updateURL:
            [.updateURL]
        case .deletion:
            [.delete]
        case .combined:
            [.create, .move, .rename, .updateURL, .delete]
        }
    }

    var trees: (source: PreviewNode, target: PreviewNode) {
        let root = { (children: [PreviewNode]) in
            PreviewNode.folder(id: 1, title: "Root", children: children)
        }
        let folder = {
            (id: Int, title: String, children: [PreviewNode]) in
            PreviewNode.folder(id: id, title: title, children: children)
        }
        let bookmark = { (id: Int, title: String, url: String) in
            PreviewNode.bookmark(id: id, title: title, url: url)
        }

        switch self {
        case .noChange:
            let tree = root([
                folder(2, "Folder", [
                    bookmark(3, "Bookmark", "https://example.com"),
                ]),
            ])
            return (tree, tree)
        case .creation, .reverseCreation:
            return (
                root([
                    folder(2, "Folder", [
                        bookmark(3, "Existing", "https://example.com/existing"),
                        bookmark(4, "Created", "https://example.com/created"),
                    ]),
                ]),
                root([
                    folder(2, "Folder", [
                        bookmark(3, "Existing", "https://example.com/existing"),
                    ]),
                ])
            )
        case .rename:
            return (
                root([
                    folder(2, "Folder", [
                        bookmark(3, "Renamed", "https://example.com"),
                    ]),
                ]),
                root([
                    folder(2, "Folder", [
                        bookmark(3, "Old name", "https://example.com"),
                    ]),
                ])
            )
        case .move:
            return (
                root([
                    folder(2, "First", []),
                    folder(3, "Second", [
                        bookmark(4, "Moved", "https://example.com/moved"),
                    ]),
                ]),
                root([
                    folder(2, "First", [
                        bookmark(4, "Moved", "https://example.com/moved"),
                    ]),
                    folder(3, "Second", []),
                ])
            )
        case .updateURL:
            return (
                root([
                    folder(2, "Folder", [
                        bookmark(3, "Bookmark", "https://example.com/new"),
                    ]),
                ]),
                root([
                    folder(2, "Folder", [
                        bookmark(3, "Bookmark", "https://example.com/old"),
                    ]),
                ])
            )
        case .deletion:
            return (
                root([folder(2, "Folder", [])]),
                root([
                    folder(2, "Folder", [
                        bookmark(3, "Deleted", "https://example.com/deleted"),
                    ]),
                ])
            )
        case .combined:
            return (
                root([
                    folder(2, "First", [
                        bookmark(5, "Created", "https://example.com/created"),
                    ]),
                    folder(3, "Second", [
                        bookmark(4, "Renamed", "https://example.com/new"),
                    ]),
                ]),
                root([
                    folder(2, "First", [
                        bookmark(4, "Old", "https://example.com/old"),
                        bookmark(6, "Deleted", "https://example.com/deleted"),
                    ]),
                    folder(3, "Second", []),
                ])
            )
        }
    }
}

private indirect enum PreviewNode: Sendable {
    case folder(id: Int, title: String, children: [PreviewNode])
    case bookmark(id: Int, title: String, url: String)

    var id: Int {
        switch self {
        case .folder(let id, _, _), .bookmark(let id, _, _):
            id
        }
    }

    var flattened: [PreviewNode] {
        switch self {
        case .folder(_, _, let children):
            [self] + children.flatMap(\.flattened)
        case .bookmark:
            [self]
        }
    }
}

private final class PreviewFixture {
    let rootURL: URL
    let safariBookmarksURL: URL
    let chromeBookmarksURL: URL
    let request: SynchronizationPreviewRequest
    let service: SynchronizationPreviewService

    private let safariData: Data
    private let chromeData: Data
    private let initialRelativePaths: [String]

    private init(
        rootURL: URL,
        safariBookmarksURL: URL,
        chromeBookmarksURL: URL,
        request: SynchronizationPreviewRequest,
        service: SynchronizationPreviewService,
        safariData: Data,
        chromeData: Data,
        initialRelativePaths: [String]
    ) {
        self.rootURL = rootURL
        self.safariBookmarksURL = safariBookmarksURL
        self.chromeBookmarksURL = chromeBookmarksURL
        self.request = request
        self.service = service
        self.safariData = safariData
        self.chromeData = chromeData
        self.initialRelativePaths = initialRelativePaths
    }

    static func make(scenario: PreviewScenario) async throws -> PreviewFixture {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookmarkBridge-BSE780-\(UUID().uuidString)")
        let safariURL = rootURL
            .appendingPathComponent("Library/Safari/Bookmarks.plist")
        let chromeURL = rootURL.appendingPathComponent(
            "Application Support/Google/Chrome/Default/Bookmarks"
        )
        for url in [safariURL, chromeURL] {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        }

        let trees = scenario.trees
        let safariTree: PreviewNode
        let chromeTree: PreviewNode
        switch scenario.direction {
        case .safariToChrome:
            safariTree = trees.source
            chromeTree = trees.target
        case .chromeToSafari:
            safariTree = trees.target
            chromeTree = trees.source
        }
        let safariData = try safariDocument(safariTree)
        let chromeData = try chromeDocument(chromeTree)
        try safariData.write(to: safariURL)
        try chromeData.write(to: chromeURL)

        let safariSourceID = BSESourceID(previewUUID(1))
        let chromeSourceID = BSESourceID(previewUUID(2))
        let profile = try ChromeProfileIdentifier("Default")
        let safariRead = try await SafariAdapter(
            sourceID: safariSourceID,
            dataSource: DefaultSafariDataSource(bookmarksFileURL: safariURL)
        ).read()
        let chromeRead = try await ChromeAdapter(
            sourceID: chromeSourceID,
            profileIdentifier: profile,
            dataSource: DefaultChromeDataSource(
                bookmarksFileURL: chromeURL,
                profileIdentifier: profile
            )
        ).read()
        let baseline = try makeBaseline(
            safari: (safariTree, safariRead.snapshot),
            chrome: (chromeTree, chromeRead.snapshot)
        )
        let service = SynchronizationPreviewService(
            baselineRepository: BaselineRepository(
                store: InMemoryBaselineStore(baseline: baseline)
            ),
            identityProvider: PreviewIdentityProvider(),
            nativeIdentityRepository: InMemoryNativeIdentityRepository()
        )
        let request = SynchronizationPreviewRequest(
            direction: scenario.direction,
            safariSourceID: safariSourceID,
            chromeSourceID: chromeSourceID,
            safariBookmarksURL: safariURL,
            chromeBookmarksURL: chromeURL,
            chromeProfileIdentifier: profile
        )
        return PreviewFixture(
            rootURL: rootURL,
            safariBookmarksURL: safariURL,
            chromeBookmarksURL: chromeURL,
            request: request,
            service: service,
            safariData: safariData,
            chromeData: chromeData,
            initialRelativePaths: try relativePaths(in: rootURL)
        )
    }

    func expectNoFileSystemMutation() throws {
        #expect(try Data(contentsOf: safariBookmarksURL) == safariData)
        #expect(try Data(contentsOf: chromeBookmarksURL) == chromeData)
        #expect(try Self.relativePaths(in: rootURL) == initialRelativePaths)
    }

    func remove() {
        try? FileManager.default.removeItem(at: rootURL)
    }

    private static func makeBaseline(
        safari: (PreviewNode, BSESnapshot),
        chrome: (PreviewNode, BSESnapshot)
    ) throws -> Baseline {
        var observationsByID: [Int: [BaselineObservation]] = [:]
        try appendObservations(
            tree: safari.0,
            snapshot: safari.1,
            to: &observationsByID
        )
        try appendObservations(
            tree: chrome.0,
            snapshot: chrome.1,
            to: &observationsByID
        )
        let records = try observationsByID.keys.sorted().map { id in
            try IdentityRecord(
                logicalNodeID: LogicalNodeID(previewUUID(20 + id)),
                revision: IdentityRevision(1),
                state: .active,
                observations: observationsByID[id] ?? [],
                metadata: IdentityRecordMetadata(
                    createdInBaselineRevision: BaselineRevision(1),
                    lastChangedInBaselineRevision: BaselineRevision(1)
                )
            )
        }
        return try Baseline(
            baselineID: BaselineID(previewUUID(250)),
            schemaVersion: .current,
            revision: BaselineRevision(1),
            identityRecords: records
        )
    }

    private static func appendObservations(
        tree: PreviewNode,
        snapshot: BSESnapshot,
        to observationsByID: inout [Int: [BaselineObservation]]
    ) throws {
        guard tree.flattened.count == snapshot.tree.nodes.count else {
            throw PreviewTestError.fixtureSnapshotMismatch
        }
        for (fixtureNode, snapshotNode) in zip(
            tree.flattened,
            snapshot.tree.nodes
        ) {
            observationsByID[fixtureNode.id, default: []].append(
                try BaselineObservation(
                    sourceID: snapshot.source,
                    provisionalLogicalID: snapshotNode.logicalID,
                    recognitionArtifacts: [],
                    firstObservedAt: snapshot.capturedAt,
                    lastObservedAt: snapshot.capturedAt,
                    presence: .present
                )
            )
        }
    }

    private static func safariDocument(_ root: PreviewNode) throws -> Data {
        var permanentRoot = safariValue(root, position: 0)
        permanentRoot["WebBookmarkIdentifier"] = "BookmarksBar"
        return try PropertyListSerialization.data(
            fromPropertyList: [
                "WebBookmarkFileVersion": 1,
                "WebBookmarkType": "WebBookmarkTypeList",
                "WebBookmarkUUID": "safari-container",
                "Title": "Safari",
                "Children": [permanentRoot],
                "PreviewFixtureMetadata": "preserved",
            ],
            format: .binary,
            options: 0
        )
    }

    private static func safariValue(
        _ node: PreviewNode,
        position: Int
    ) -> [String: Any] {
        switch node {
        case .folder(let id, let title, let children):
            [
                "WebBookmarkType": "WebBookmarkTypeList",
                "WebBookmarkUUID": "safari-\(id)",
                "Title": title,
                "Children": children.enumerated().map {
                    safariValue($0.element, position: $0.offset)
                },
                "PreviewFixtureMetadata": "preserved",
            ]
        case .bookmark(let id, let title, let url):
            [
                "WebBookmarkType": "WebBookmarkTypeLeaf",
                "WebBookmarkUUID": "safari-\(id)",
                "URIDictionary": ["title": title],
                "URLString": url,
                "PreviewFixtureMetadata": position,
            ]
        }
    }

    private static func chromeDocument(_ root: PreviewNode) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [
                "version": 1,
                "roots": [
                    "bookmark_bar": chromeValue(root, position: 0),
                ],
                "preview_fixture_metadata": "preserved",
            ],
            options: [.sortedKeys]
        )
    }

    private static func chromeValue(
        _ node: PreviewNode,
        position: Int
    ) -> [String: Any] {
        switch node {
        case .folder(let id, let title, let children):
            [
                "type": "folder",
                "id": String(id),
                "guid": "chrome-\(id)",
                "name": title,
                "children": children.enumerated().map {
                    chromeValue($0.element, position: $0.offset)
                },
                "date_added": "13200000000000000",
                "meta_info": ["fixture": "preserved"],
            ]
        case .bookmark(let id, let title, let url):
            [
                "type": "url",
                "id": String(id),
                "guid": "chrome-\(id)",
                "name": title,
                "url": url,
                "date_added": "13200000000000000",
                "preview_fixture_position": position,
            ]
        }
    }

    private static func relativePaths(in rootURL: URL) throws -> [String] {
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }
        return enumerator.compactMap { element in
            guard let url = element as? URL else { return nil }
            return String(url.path.dropFirst(rootURL.path.count + 1))
        }.sorted()
    }
}

private enum PreviewTestError: Error {
    case fixtureSnapshotMismatch
}

private final class PreviewIdentityProvider: IdentityProvider {
    private let nextValue = Mutex(100)

    func nextLogicalNodeID() throws -> LogicalNodeID {
        LogicalNodeID(previewUUID(nextValue.withLock {
            let value = $0
            $0 += 1
            return value
        }))
    }
}

private func previewUUID(_ value: Int) -> UUID {
    let high = UInt8(truncatingIfNeeded: value >> 8)
    let low = UInt8(truncatingIfNeeded: value)
    return UUID(uuid: (
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, high, low
    ))
}
