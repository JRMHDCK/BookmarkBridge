//
//  ProductionSynchronizationServiceTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Synchronization
import Testing
@testable import BookmarkBridge

@Suite("BSE-770 Production Synchronization")
struct ProductionSynchronizationServiceTests {
    @Test(
        "Concrete production composition applies supported changes",
        arguments: ProductionScenario.allCases
    )
    func appliesScenario(_ scenario: ProductionScenario) async throws {
        let fixture = try await ProductionFixture.make(scenario: scenario)
        defer { fixture.remove() }

        let confirmedPlan = try await fixture.confirmedPlan()
        let result = try await fixture.service.synchronize(
            confirmedPlan: confirmedPlan
        )

        #expect(result.direction == scenario.direction)
        #expect(result.synchronization.diffAfter.changes.isEmpty)
        #expect(
            result.synchronization.plan.phases.flatMap(\.operations).map(\.kind)
                == scenario.expectedOperationKinds
        )
        #expect(result.synchronization.execution.status == .completed)
        if scenario.expectedOperationKinds.isEmpty {
            #expect(result.transaction.backup == nil)
            #expect(result.transaction.appliedOperationCount == 0)
            #expect(try fixture.backupCount == 0)
        } else {
            #expect(result.transaction.backup != nil)
            #expect(
                result.transaction.appliedOperationCount
                    == scenario.expectedOperationKinds.count
            )
            #expect(try fixture.backupCount == 1)
        }
        try fixture.expectOriginalFixturesUnchanged()
    }

    @Test(
        "A second production synchronization is a no-op",
        arguments: [
            ProductionScenario.creation,
            ProductionScenario.reverseCreation,
        ]
    )
    func secondSynchronizationIsANoOp(
        _ scenario: ProductionScenario
    ) async throws {
        let fixture = try await ProductionFixture.make(scenario: scenario)
        defer { fixture.remove() }

        let firstConfirmation = try await fixture.confirmedPlan()
        let first = try await fixture.service.synchronize(
            confirmedPlan: firstConfirmation
        )
        let secondConfirmation = try await fixture.confirmedPlan()
        let second = try await fixture.service.synchronize(
            confirmedPlan: secondConfirmation
        )

        #expect(!first.synchronization.plan.phases.flatMap(\.operations).isEmpty)
        #expect(second.synchronization.diffBefore.changes.isEmpty)
        #expect(second.synchronization.plan.phases.flatMap(\.operations).isEmpty)
        #expect(second.synchronization.execution.report.plannedOperationCount == 0)
        #expect(second.synchronization.diffAfter.changes.isEmpty)
        try fixture.expectOriginalFixturesUnchanged()
    }

    @Test(
        "Position-dependent production plans are executable and immediately stable",
        arguments: [
            ProductionScenario.positionDependentCreation,
        ]
    )
    func positionDependentPlanIsStable(
        _ scenario: ProductionScenario
    ) async throws {
        let fixture = try await ProductionFixture.make(scenario: scenario)
        defer { fixture.remove() }

        let first = try await fixture.synchronizeConfirmedPlan()
        let second = try await fixture.synchronizeConfirmedPlan()

        #expect(
            first.synchronization.plan.operations.map(\.kind)
                == [.create, .move]
        )
        #expect(first.synchronization.diffAfter.changes.isEmpty)
        #expect(second.synchronization.diffBefore.changes.isEmpty)
        #expect(second.synchronization.plan.operations.isEmpty)
        #expect(second.synchronization.diffAfter.changes.isEmpty)
        try fixture.expectOriginalFixturesUnchanged()
    }

    @Test(
        "An empty Baseline reuses written native identities on later passes",
        arguments: [
            ProductionScenario.hierarchicalCreation,
        ]
    )
    func emptyBaselineIsStableAcrossThreePasses(
        _ scenario: ProductionScenario
    ) async throws {
        let fixture = try await ProductionFixture.make(
            scenario: scenario,
            emptyBaseline: true
        )
        defer { fixture.remove() }

        let first = try await fixture.synchronizeConfirmedPlan()
        let permanentRootIDs = Set(
            first.synchronization.projectionBefore.before.nodes
                .filter { $0.permanentRootRole != nil }
                .map(\.logicalNodeID)
            + first.synchronization.projectionBefore.after.nodes
                .filter { $0.permanentRootRole != nil }
                .map(\.logicalNodeID)
        )
        let firstOperations = first.synchronization.plan.phases
            .flatMap(\.operations)

        #expect(!firstOperations.isEmpty)
        #expect(first.synchronization.diffAfter.changes.isEmpty)
        #expect(
            firstOperations.allSatisfy {
                !permanentRootIDs.contains($0.logicalNodeID)
            }
        )

        let second = try await fixture.synchronizeConfirmedPlan()
        let third = try await fixture.synchronizeConfirmedPlan()

        #expect(second.synchronization.diffBefore.changes.isEmpty)
        #expect(second.synchronization.plan.phases.flatMap(\.operations).isEmpty)
        #expect(second.synchronization.diffAfter.changes.isEmpty)
        #expect(third.synchronization.diffBefore.changes.isEmpty)
        #expect(third.synchronization.plan.phases.flatMap(\.operations).isEmpty)
        #expect(third.synchronization.diffAfter.changes.isEmpty)
        try fixture.expectOriginalFixturesUnchanged()
    }

    @Test(
        "A created folder keeps its durable identity when renamed and moved",
        arguments: [
            ProductionScenario.hierarchicalCreation,
        ]
    )
    func createdFolderCanThenBeRenamedAndMoved(
        _ scenario: ProductionScenario
    ) async throws {
        let fixture = try await ProductionFixture.make(
            scenario: scenario,
            emptyBaseline: true
        )
        defer { fixture.remove() }

        _ = try await fixture.synchronizeConfirmedPlan()
        try fixture.replaceSourceTree(with: .folder(
            id: 1,
            title: "Root",
            children: [
                .folder(id: 2, title: "Parent Renamed", children: []),
                .folder(id: 5, title: "Independent", children: [
                    .bookmark(
                        id: 6,
                        title: "Independent Bookmark",
                        url: "https://example.com/independent"
                    ),
                    .folder(id: 3, title: "Child", children: [
                        .bookmark(
                            id: 4,
                            title: "Nested",
                            url: "https://example.com/nested"
                        ),
                    ]),
                ]),
            ]
        ))

        let changed = try await fixture.synchronizeConfirmedPlan()
        let changedKinds = changed.synchronization.plan.phases
            .flatMap(\.operations)
            .map(\.kind)
        let stable = try await fixture.synchronizeConfirmedPlan()

        #expect(changedKinds.contains(.rename))
        #expect(changedKinds.contains(.move))
        #expect(changed.synchronization.diffAfter.changes.isEmpty)
        #expect(stable.synchronization.diffBefore.changes.isEmpty)
        #expect(stable.synchronization.plan.phases.flatMap(\.operations).isEmpty)
        #expect(stable.synchronization.diffAfter.changes.isEmpty)
        try fixture.expectOriginalFixturesUnchanged()
    }

    @Test("A source read failure is explicit and leaves fixtures untouched")
    func sourceReadFailure() async throws {
        let fixture = try await ProductionFixture.make(scenario: .creation)
        defer { fixture.remove() }
        let confirmedPlan = try await fixture.confirmedPlan()
        try FileManager.default.removeItem(at: fixture.safariBookmarksURL)

        await #expect(throws: ProductionSynchronizationError.self) {
            _ = try await fixture.service.synchronize(
                confirmedPlan: confirmedPlan
            )
        }
        try fixture.expectOriginalFixturesUnchanged()
    }

    @Test("An open Chrome blocks the transaction before backup or write")
    func targetSaveFailure() async throws {
        let fixture = try await ProductionFixture.make(
            scenario: .creation,
            chromeIsOpen: true
        )
        defer { fixture.remove() }
        let confirmedPlan = try await fixture.confirmedPlan()
        let targetBefore = try Data(contentsOf: fixture.chromeBookmarksURL)
        let baselineBefore = try await fixture.baselineRepository.load()
        let identitiesBefore =
            try fixture.nativeIdentityRepository.transactionSnapshot()

        await #expect(throws: ProductionSynchronizationError.self) {
            _ = try await fixture.service.synchronize(
                confirmedPlan: confirmedPlan
            )
        }

        #expect(try Data(contentsOf: fixture.chromeBookmarksURL) == targetBefore)
        #expect(try await fixture.baselineRepository.load() == baselineBefore)
        #expect(
            try fixture.nativeIdentityRepository.transactionSnapshot()
                == identitiesBefore
        )
        #expect(try fixture.backupCount == 0)
        try fixture.expectOriginalFixturesUnchanged()
    }

    @Test("An open Safari blocks the transaction before backup or write")
    func reverseTargetSaveFailure() async throws {
        let fixture = try await ProductionFixture.make(
            scenario: .reverseCreation,
            safariIsOpen: true
        )
        defer { fixture.remove() }
        let confirmedPlan = try await fixture.confirmedPlan()
        let targetBefore = try Data(contentsOf: fixture.safariBookmarksURL)
        let baselineBefore = try await fixture.baselineRepository.load()
        let identitiesBefore =
            try fixture.nativeIdentityRepository.transactionSnapshot()

        await #expect(throws: ProductionSynchronizationError.self) {
            _ = try await fixture.service.synchronize(
                confirmedPlan: confirmedPlan
            )
        }

        #expect(try Data(contentsOf: fixture.safariBookmarksURL) == targetBefore)
        #expect(try await fixture.baselineRepository.load() == baselineBefore)
        #expect(
            try fixture.nativeIdentityRepository.transactionSnapshot()
                == identitiesBefore
        )
        #expect(try fixture.backupCount == 0)
        try fixture.expectOriginalFixturesUnchanged()
    }

    @Test(
        "Safari to Chrome later failure rolls back prior native registrations"
    )
    func laterChromeFailureRollsBackPersistentState() async throws {
        let fixture = try await ProductionFixture.make(
            scenario: .hierarchicalCreation,
            chromeOpenOnSaveAttempt: 3
        )
        defer { fixture.remove() }
        let confirmedPlan = try await fixture.confirmedPlan()
        let targetBefore = try Data(contentsOf: fixture.chromeBookmarksURL)
        let baselineBefore = try await fixture.baselineRepository.load()
        let identitiesBefore =
            try fixture.nativeIdentityRepository.transactionSnapshot()

        await #expect(throws: SynchronizationTransactionError.self) {
            _ = try await fixture.service.synchronize(
                confirmedPlan: confirmedPlan
            )
        }

        #expect(try Data(contentsOf: fixture.chromeBookmarksURL) == targetBefore)
        #expect(try await fixture.baselineRepository.load() == baselineBefore)
        #expect(
            try fixture.nativeIdentityRepository.transactionSnapshot()
                == identitiesBefore
        )
    }

    @Test("Chrome to Safari later failure rolls back prior native registrations")
    func laterSafariFailureRollsBackPersistentState() async throws {
        let fixture = try await ProductionFixture.make(
            scenario: .reverseHierarchicalCreation,
            safariOpenOnSaveAttempt: 3
        )
        defer { fixture.remove() }
        let confirmedPlan = try await fixture.confirmedPlan()
        let targetBefore = try Data(contentsOf: fixture.safariBookmarksURL)
        let baselineBefore = try await fixture.baselineRepository.load()
        let identitiesBefore =
            try fixture.nativeIdentityRepository.transactionSnapshot()

        await #expect(throws: SynchronizationTransactionError.self) {
            _ = try await fixture.service.synchronize(
                confirmedPlan: confirmedPlan
            )
        }

        #expect(try Data(contentsOf: fixture.safariBookmarksURL) == targetBefore)
        #expect(try await fixture.baselineRepository.load() == baselineBefore)
        #expect(
            try fixture.nativeIdentityRepository.transactionSnapshot()
                == identitiesBefore
        )
    }

    @Test(
        "Safari to Chrome later delete failure restores removed identities"
    )
    func laterChromeDeleteFailureRollsBackPersistentState() async throws {
        let fixture = try await ProductionFixture.make(
            scenario: .multipleDeletions,
            chromeOpenOnSaveAttempt: 3
        )
        defer { fixture.remove() }
        let confirmedPlan = try await fixture.confirmedPlan()
        let targetBefore = try Data(contentsOf: fixture.chromeBookmarksURL)
        let baselineBefore = try await fixture.baselineRepository.load()
        let identitiesBefore =
            try fixture.nativeIdentityRepository.transactionSnapshot()

        await #expect(throws: SynchronizationTransactionError.self) {
            _ = try await fixture.service.synchronize(
                confirmedPlan: confirmedPlan
            )
        }

        #expect(try Data(contentsOf: fixture.chromeBookmarksURL) == targetBefore)
        #expect(try await fixture.baselineRepository.load() == baselineBefore)
        #expect(
            try fixture.nativeIdentityRepository.transactionSnapshot()
                == identitiesBefore
        )
    }

    @Test("Chrome to Safari later delete failure restores removed identities")
    func laterSafariDeleteFailureRollsBackPersistentState() async throws {
        let fixture = try await ProductionFixture.make(
            scenario: .reverseMultipleDeletions,
            safariOpenOnSaveAttempt: 3
        )
        defer { fixture.remove() }
        let confirmedPlan = try await fixture.confirmedPlan()
        let targetBefore = try Data(contentsOf: fixture.safariBookmarksURL)
        let baselineBefore = try await fixture.baselineRepository.load()
        let identitiesBefore =
            try fixture.nativeIdentityRepository.transactionSnapshot()

        await #expect(throws: SynchronizationTransactionError.self) {
            _ = try await fixture.service.synchronize(
                confirmedPlan: confirmedPlan
            )
        }

        #expect(try Data(contentsOf: fixture.safariBookmarksURL) == targetBefore)
        #expect(try await fixture.baselineRepository.load() == baselineBefore)
        #expect(
            try fixture.nativeIdentityRepository.transactionSnapshot()
                == identitiesBefore
        )
    }

    @Test("A source change after confirmation refuses all target writes")
    func sourceChangeAfterConfirmation() async throws {
        let fixture = try await ProductionFixture.make(scenario: .creation)
        defer { fixture.remove() }
        let confirmedPlan = try await fixture.confirmedPlan()
        let targetBefore = try Data(contentsOf: fixture.chromeBookmarksURL)

        try fixture.replaceSafariTree(with: ProductionScenario.rename.trees.source)

        await #expect(throws: PlanConfirmationError.planChanged) {
            _ = try await fixture.service.synchronize(
                confirmedPlan: confirmedPlan
            )
        }

        #expect(try Data(contentsOf: fixture.chromeBookmarksURL) == targetBefore)
        #expect(!fixture.backupWasCreated)
    }

    @Test("A target change after confirmation refuses all writes")
    func targetChangeAfterConfirmation() async throws {
        let fixture = try await ProductionFixture.make(scenario: .creation)
        defer { fixture.remove() }
        let confirmedPlan = try await fixture.confirmedPlan()

        try fixture.replaceChromeTree(with: ProductionScenario.rename.trees.target)
        let externallyChangedTarget = try Data(
            contentsOf: fixture.chromeBookmarksURL
        )

        await #expect(throws: PlanConfirmationError.planChanged) {
            _ = try await fixture.service.synchronize(
                confirmedPlan: confirmedPlan
            )
        }

        #expect(
            try Data(contentsOf: fixture.chromeBookmarksURL)
                == externallyChangedTarget
        )
        #expect(!fixture.backupWasCreated)
    }

    @Test("A changed confirmed fingerprint is rejected before writing")
    func changedConfirmedFingerprint() async throws {
        let fixture = try await ProductionFixture.make(scenario: .creation)
        defer { fixture.remove() }
        let confirmedPlan = try await fixture.confirmedPlan()
        let targetBefore = try Data(contentsOf: fixture.chromeBookmarksURL)
        let changedConfirmation = ConfirmedSynchronizationPlan(
            direction: confirmedPlan.direction,
            plan: confirmedPlan.plan,
            planFingerprint: SynchronizationPlanFingerprint(
                rawValue: String(repeating: "0", count: 64)
            ),
            sourceSnapshotFingerprint:
                confirmedPlan.sourceSnapshotFingerprint,
            targetSnapshotFingerprint:
                confirmedPlan.targetSnapshotFingerprint,
            executionRequest: confirmedPlan.executionRequest
        )

        await #expect(throws: PlanConfirmationError.planChanged) {
            _ = try await fixture.service.synchronize(
                confirmedPlan: changedConfirmation
            )
        }

        #expect(try Data(contentsOf: fixture.chromeBookmarksURL) == targetBefore)
        #expect(!fixture.backupWasCreated)
    }
}

enum ProductionScenario: String, CaseIterable, Sendable {
    case noChange
    case creation
    case reverseCreation
    case hierarchicalCreation
    case reverseHierarchicalCreation
    case positionDependentCreation
    case reversePositionDependentCreation
    case rename
    case move
    case updateURL
    case deletion
    case multipleDeletions
    case reverseMultipleDeletions
    case combined

    var direction: ProductionSynchronizationDirection {
        switch self {
        case .reverseCreation, .reverseHierarchicalCreation,
             .reversePositionDependentCreation, .reverseMultipleDeletions:
            .chromeToSafari
        default:
            .safariToChrome
        }
    }

    var expectedOperationKinds: [SynchronizationOperation.Kind] {
        switch self {
        case .noChange:
            []
        case .creation, .reverseCreation:
            [.create]
        case .hierarchicalCreation, .reverseHierarchicalCreation:
            [.create, .create, .create, .create, .create]
        case .positionDependentCreation, .reversePositionDependentCreation:
            [.create, .move]
        case .rename:
            [.rename]
        case .move:
            [.move]
        case .updateURL:
            [.updateURL]
        case .deletion:
            [.delete]
        case .multipleDeletions, .reverseMultipleDeletions:
            [.delete, .delete]
        case .combined:
            [.create, .move, .rename, .updateURL, .delete]
        }
    }

    var trees: (source: FixtureNode, target: FixtureNode) {
        let root = { (children: [FixtureNode]) in
            FixtureNode.folder(id: 1, title: "Root", children: children)
        }
        let folder = { (id: Int, title: String, children: [FixtureNode]) in
            FixtureNode.folder(id: id, title: title, children: children)
        }
        let bookmark = { (id: Int, title: String, url: String) in
            FixtureNode.bookmark(id: id, title: title, url: url)
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
        case .hierarchicalCreation, .reverseHierarchicalCreation:
            return (
                root([
                    folder(2, "Parent", [
                        folder(3, "Child", [
                            bookmark(
                                4,
                                "Nested",
                                "https://example.com/nested"
                            ),
                        ]),
                    ]),
                    folder(5, "Independent", [
                        bookmark(
                            6,
                            "Independent Bookmark",
                            "https://example.com/independent"
                        ),
                    ]),
                ]),
                root([])
            )
        case .positionDependentCreation, .reversePositionDependentCreation:
            return (
                root([
                    folder(2, "Destination", [
                        bookmark(4, "Moved", "https://example.com/moved"),
                        bookmark(5, "Created", "https://example.com/created"),
                    ]),
                    folder(3, "Origin", []),
                ]),
                root([
                    folder(2, "Destination", []),
                    folder(3, "Origin", [
                        bookmark(4, "Moved", "https://example.com/moved"),
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
        case .multipleDeletions, .reverseMultipleDeletions:
            return (
                root([folder(2, "Folder", [])]),
                root([
                    folder(2, "Folder", [
                        bookmark(3, "First", "https://example.com/first"),
                        bookmark(4, "Second", "https://example.com/second"),
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

extension SynchronizationOperation {
    enum Kind: Hashable {
        case create
        case delete
        case rename
        case updateURL
        case move
        case reorder
        case archive
    }

    var kind: Kind {
        switch self {
        case .create: .create
        case .delete: .delete
        case .rename: .rename
        case .updateURL: .updateURL
        case .move: .move
        case .reorder: .reorder
        case .archive: .archive
        }
    }
}

indirect enum FixtureNode: Sendable {
    case folder(id: Int, title: String, children: [FixtureNode])
    case bookmark(id: Int, title: String, url: String)

    var id: Int {
        switch self {
        case .folder(let id, _, _), .bookmark(let id, _, _):
            id
        }
    }

    var flattened: [FixtureNode] {
        switch self {
        case .folder(_, _, let children):
            [self] + children.flatMap(\.flattened)
        case .bookmark:
            [self]
        }
    }
}

private final class ProductionFixture {
    let rootURL: URL
    let originalSafariURL: URL
    let originalChromeURL: URL
    let safariBookmarksURL: URL
    let chromeBookmarksURL: URL
    let request: ProductionSynchronizationRequest
    let service: ProductionSynchronizationService
    let previewService: SynchronizationPreviewService
    let baselineRepository: BaselineRepository
    let nativeIdentityRepository: InMemoryNativeIdentityRepository

    private let originalSafariData: Data
    private let originalChromeData: Data

    private init(
        rootURL: URL,
        originalSafariURL: URL,
        originalChromeURL: URL,
        safariBookmarksURL: URL,
        chromeBookmarksURL: URL,
        request: ProductionSynchronizationRequest,
        service: ProductionSynchronizationService,
        previewService: SynchronizationPreviewService,
        baselineRepository: BaselineRepository,
        nativeIdentityRepository: InMemoryNativeIdentityRepository,
        originalSafariData: Data,
        originalChromeData: Data
    ) {
        self.rootURL = rootURL
        self.originalSafariURL = originalSafariURL
        self.originalChromeURL = originalChromeURL
        self.safariBookmarksURL = safariBookmarksURL
        self.chromeBookmarksURL = chromeBookmarksURL
        self.request = request
        self.service = service
        self.previewService = previewService
        self.baselineRepository = baselineRepository
        self.nativeIdentityRepository = nativeIdentityRepository
        self.originalSafariData = originalSafariData
        self.originalChromeData = originalChromeData
    }

    static func make(
        scenario: ProductionScenario,
        chromeIsOpen: Bool = false,
        safariIsOpen: Bool = false,
        chromeOpenOnSaveAttempt: Int? = nil,
        safariOpenOnSaveAttempt: Int? = nil,
        emptyBaseline: Bool = false
    ) async throws -> ProductionFixture {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookmarkBridge-BSE770-\(UUID().uuidString)")
        let originalsURL = rootURL.appendingPathComponent("Fixtures")
        let workURL = rootURL.appendingPathComponent("Work")
        let originalSafariURL = originalsURL
            .appendingPathComponent("Safari/Bookmarks.plist")
        let originalChromeURL = originalsURL
            .appendingPathComponent("Chrome/Bookmarks")
        let safariBookmarksURL = workURL
            .appendingPathComponent("Library/Safari/Bookmarks.plist")
        let chromeBookmarksURL = workURL
            .appendingPathComponent(
                "Application Support/Google/Chrome/Default/Bookmarks"
            )
        let safariBackupURL = rootURL.appendingPathComponent("Backups/Safari")
        let chromeBackupURL = rootURL.appendingPathComponent("Backups/Chrome")

        for url in [
            originalSafariURL,
            originalChromeURL,
            safariBookmarksURL,
            chromeBookmarksURL,
        ] {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        }

        let trees = scenario.trees
        let safariTree: FixtureNode
        let chromeTree: FixtureNode
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
        try safariData.write(to: originalSafariURL)
        try chromeData.write(to: originalChromeURL)
        try safariData.write(to: safariBookmarksURL)
        try chromeData.write(to: chromeBookmarksURL)

        let safariSourceID = BSESourceID(testUUID(1))
        let chromeSourceID = BSESourceID(testUUID(2))
        let profile = try ChromeProfileIdentifier("Default")
        let safariRead = try await SafariAdapter(
            sourceID: safariSourceID,
            dataSource: DefaultSafariDataSource(
                bookmarksFileURL: safariBookmarksURL
            )
        ).read()
        let chromeRead = try await ChromeAdapter(
            sourceID: chromeSourceID,
            profileIdentifier: profile,
            dataSource: DefaultChromeDataSource(
                bookmarksFileURL: chromeBookmarksURL,
                profileIdentifier: profile
            )
        ).read()
        let baseline = try emptyBaseline
            ? Baseline.empty(baselineID: BaselineID(testUUID(250)))
            : makeBaseline(
                safari: (safariTree, safariRead.snapshot),
                chrome: (chromeTree, chromeRead.snapshot)
            )
        let baselineRepository = BaselineRepository(
            store: InMemoryBaselineStore(baseline: baseline)
        )
        let identityProvider = SequentialIdentityProvider()
        let nativeIdentityRepository = InMemoryNativeIdentityRepository()
        let safariSaveCheckCount = Mutex(0)
        let chromeSaveCheckCount = Mutex(0)
        let service = ProductionSynchronizationService(
            baselineRepository: baselineRepository,
            identityProvider: identityProvider,
            nativeIdentityRepository: nativeIdentityRepository,
            nativeIdentifierProvider: SequentialNativeIdentifierProvider(),
            safariApplicationStateChecker: SafariApplicationStateChecker {
                if safariIsOpen {
                    return true
                }
                guard let safariOpenOnSaveAttempt else {
                    return false
                }
                return safariSaveCheckCount.withLock {
                    $0 += 1
                    return $0 == safariOpenOnSaveAttempt
                }
            },
            chromeApplicationStateChecker: ChromeApplicationStateChecker {
                if chromeIsOpen {
                    return true
                }
                guard let chromeOpenOnSaveAttempt else {
                    return false
                }
                return chromeSaveCheckCount.withLock {
                    $0 += 1
                    return $0 == chromeOpenOnSaveAttempt
                }
            },
            safariAdapterIdentifier: WriteAdapterIdentifier(testUUID(240)),
            chromeAdapterIdentifier: WriteAdapterIdentifier(testUUID(241))
        )
        let previewService = SynchronizationPreviewService(
            baselineRepository: baselineRepository,
            identityProvider: identityProvider,
            nativeIdentityRepository: nativeIdentityRepository
        )
        let request = ProductionSynchronizationRequest(
            direction: scenario.direction,
            safariSourceID: safariSourceID,
            chromeSourceID: chromeSourceID,
            safariBookmarksURL: safariBookmarksURL,
            chromeBookmarksURL: chromeBookmarksURL,
            safariBackupDirectoryURL: safariBackupURL,
            chromeBackupDirectoryURL: chromeBackupURL,
            chromeProfileIdentifier: profile
        )
        return ProductionFixture(
            rootURL: rootURL,
            originalSafariURL: originalSafariURL,
            originalChromeURL: originalChromeURL,
            safariBookmarksURL: safariBookmarksURL,
            chromeBookmarksURL: chromeBookmarksURL,
            request: request,
            service: service,
            previewService: previewService,
            baselineRepository: baselineRepository,
            nativeIdentityRepository: nativeIdentityRepository,
            originalSafariData: safariData,
            originalChromeData: chromeData
        )
    }

    func confirmedPlan() async throws -> ConfirmedSynchronizationPlan {
        let preview = try await previewService.preview(
            request: SynchronizationPreviewRequest(
                direction: request.direction,
                safariSourceID: request.safariSourceID,
                chromeSourceID: request.chromeSourceID,
                safariBookmarksURL: request.safariBookmarksURL,
                chromeBookmarksURL: request.chromeBookmarksURL,
                chromeProfileIdentifier: request.chromeProfileIdentifier
            )
        )
        return try ConfirmedSynchronizationPlan(
            confirming: preview,
            executionRequest: request
        )
    }

    func synchronizeConfirmedPlan() async throws
        -> ProductionSynchronizationResult {
        try await service.synchronize(confirmedPlan: confirmedPlan())
    }

    func expectOriginalFixturesUnchanged() throws {
        #expect(try Data(contentsOf: originalSafariURL) == originalSafariData)
        #expect(try Data(contentsOf: originalChromeURL) == originalChromeData)
    }

    func expectWorkingFilesUnchanged() throws {
        #expect(try Data(contentsOf: safariBookmarksURL) == originalSafariData)
        #expect(try Data(contentsOf: chromeBookmarksURL) == originalChromeData)
    }

    var backupWasCreated: Bool {
        FileManager.default.fileExists(
            atPath: request.safariBackupDirectoryURL.path
        ) || FileManager.default.fileExists(
            atPath: request.chromeBackupDirectoryURL.path
        )
    }

    var backupCount: Int {
        get throws {
            let directoryURL: URL
            switch request.direction {
            case .safariToChrome:
                directoryURL = request.chromeBackupDirectoryURL
            case .chromeToSafari:
                directoryURL = request.safariBackupDirectoryURL
            }
            guard FileManager.default.fileExists(atPath: directoryURL.path) else {
                return 0
            }
            return try FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: nil
            ).count
        }
    }

    func replaceSafariTree(with tree: FixtureNode) throws {
        try Self.safariDocument(tree).write(to: safariBookmarksURL)
    }

    func replaceChromeTree(with tree: FixtureNode) throws {
        try Self.chromeDocument(tree).write(to: chromeBookmarksURL)
    }

    func replaceSourceTree(with tree: FixtureNode) throws {
        switch request.direction {
        case .safariToChrome:
            try replaceSafariTree(with: tree)
        case .chromeToSafari:
            try replaceChromeTree(with: tree)
        }
    }

    func remove() {
        try? FileManager.default.removeItem(at: rootURL)
    }

    private static func makeBaseline(
        safari: (FixtureNode, BSESnapshot),
        chrome: (FixtureNode, BSESnapshot)
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
                logicalNodeID: LogicalNodeID(testUUID(20 + id)),
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
            baselineID: BaselineID(testUUID(250)),
            schemaVersion: .current,
            revision: BaselineRevision(1),
            identityRecords: records
        )
    }

    private static func appendObservations(
        tree: FixtureNode,
        snapshot: BSESnapshot,
        to observationsByID: inout [Int: [BaselineObservation]]
    ) throws {
        let fixtureNodes = tree.flattened
        guard fixtureNodes.count == snapshot.tree.nodes.count else {
            throw ProductionTestError.fixtureSnapshotMismatch
        }
        for (fixtureNode, snapshotNode) in zip(
            fixtureNodes,
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

    private static func safariDocument(_ root: FixtureNode) throws -> Data {
        var permanentRoot = safariValue(root, position: 0)
        permanentRoot["WebBookmarkIdentifier"] = "BookmarksBar"
        return try PropertyListSerialization.data(
            fromPropertyList: [
                "WebBookmarkFileVersion": 1,
                "WebBookmarkType": "WebBookmarkTypeList",
                "WebBookmarkUUID": "safari-container",
                "Title": "Safari",
                "Children": [permanentRoot],
                "ProductionFixtureMetadata": "preserved",
            ],
            format: .binary,
            options: 0
        )
    }

    private static func safariValue(
        _ node: FixtureNode,
        position: Int
    ) -> [String: Any] {
        switch node {
        case .folder(let id, let title, let children):
            return [
                "WebBookmarkType": "WebBookmarkTypeList",
                "WebBookmarkUUID": "safari-\(id)",
                "Title": title,
                "Children": children.enumerated().map {
                    safariValue($0.element, position: $0.offset)
                },
                "ProductionFixtureMetadata": "preserved",
            ]
        case .bookmark(let id, let title, let url):
            return [
                "WebBookmarkType": "WebBookmarkTypeLeaf",
                "WebBookmarkUUID": "safari-\(id)",
                "URIDictionary": ["title": title],
                "URLString": url,
                "ProductionFixtureMetadata": position,
            ]
        }
    }

    private static func chromeDocument(_ root: FixtureNode) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [
                "version": 1,
                "roots": [
                    "bookmark_bar": chromeValue(root, position: 0),
                ],
                "production_fixture_metadata": "preserved",
            ],
            options: [.sortedKeys]
        )
    }

    private static func chromeValue(
        _ node: FixtureNode,
        position: Int
    ) -> [String: Any] {
        switch node {
        case .folder(let id, let title, let children):
            return [
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
            return [
                "type": "url",
                "id": String(id),
                "guid": "chrome-\(id)",
                "name": title,
                "url": url,
                "date_added": "13200000000000000",
                "production_fixture_position": position,
            ]
        }
    }
}

private enum ProductionTestError: Error {
    case fixtureSnapshotMismatch
    case identityProviderExhausted
}

private final class SequentialIdentityProvider: IdentityProvider {
    private let nextValue = Mutex(100)

    func nextLogicalNodeID() throws -> LogicalNodeID {
        LogicalNodeID(testUUID(nextValue.withLock {
            let value = $0
            $0 += 1
            return value
        }))
    }
}

private final class SequentialNativeIdentifierProvider:
    NativeIdentifierProviding
{
    private let nextValue = Mutex(1_000)

    func makeIdentifier() throws -> NativeNodeIdentifier {
        let value = nextValue.withLock {
            let value = $0
            $0 += 1
            return value
        }
        return NativeNodeIdentifier("generated-\(value)")
    }
}

private func testUUID(_ value: Int) -> UUID {
    let high = UInt8(truncatingIfNeeded: value >> 8)
    let low = UInt8(truncatingIfNeeded: value)
    return UUID(uuid: (
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, high, low
    ))
}
