//
//  SynchronizationTransactionCoordinatorTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Synchronization
import Testing
@testable import BookmarkBridge

@Suite("BSE-792 Synchronization Transaction")
struct SynchronizationTransactionCoordinatorTests {
    @Test("A successful transaction retains one global backup")
    func success() async throws {
        let fixture = try TransactionFixture(operationCount: 3)
        defer { fixture.remove() }

        let result = try await fixture.execute()

        #expect(result.appliedOperationCount == 3)
        #expect(result.restorationStatus == .notRequired)
        #expect(result.backup?.targetURL == fixture.targetURL)
        #expect(result.backup.map { FileManager.default.fileExists(
            atPath: $0.backupURL.path
        ) } == true)
        #expect(try fixture.backupCount() == 1)
        #expect(try fixture.targetData() != fixture.originalData)
        #expect(try fixture.backupData() == fixture.originalData)
    }

    @Test("A first-operation failure restores the original bytes")
    func firstOperationFailure() async throws {
        let fixture = try TransactionFixture(
            operationCount: 3,
            failingOperationIndex: 0
        )
        defer { fixture.remove() }

        let failure = await fixture.executionFailure()

        #expect(failure?.failedOperation?.logicalNodeID == transactionID(1))
        #expect(failure?.appliedOperationCount == 0)
        #expect(failure?.restorationStatus == .succeeded)
        #expect(try fixture.targetData() == fixture.originalData)
        #expect(try fixture.backupCount() == 1)
    }

    @Test(
        "A later failure restores bytes after every preceding write",
        arguments: [1, 3]
    )
    func laterOperationFailure(appliedCount: Int) async throws {
        let fixture = try TransactionFixture(
            operationCount: appliedCount + 1,
            failingOperationIndex: appliedCount
        )
        defer { fixture.remove() }

        let failure = await fixture.executionFailure()

        #expect(
            failure?.failedOperation?.logicalNodeID
                == transactionID(appliedCount + 1)
        )
        #expect(failure?.appliedOperationCount == appliedCount)
        #expect(failure?.restorationStatus == .succeeded)
        #expect(try fixture.targetData() == fixture.originalData)
        #expect(try fixture.backupCount() == 1)
    }

    @Test("Backup creation failure prevents the Executor from running")
    func backupCreationFailure() async throws {
        let fixture = try TransactionFixture(operationCount: 2)
        defer { fixture.remove() }
        let manager = RecordingBackupManager(createFails: true)
        let coordinator = fixture.coordinator(backupManager: manager)
        let bodyCalled = Mutex(false)

        await #expect(
            throws: SynchronizationTransactionError.self
        ) {
            _ = try await coordinator.execute { _, _ in
                bodyCalled.withLock { $0 = true }
            }
        }

        #expect(!bodyCalled.withLock { $0 })
        #expect(manager.createCount == 1)
        #expect(manager.restoreCount == 0)
        #expect(try fixture.targetData() == fixture.originalData)
    }

    @Test("A restoration failure is explicit and retains recovery context")
    func restorationFailure() async throws {
        let fixture = try TransactionFixture(
            operationCount: 2,
            failingOperationIndex: 1
        )
        defer { fixture.remove() }
        let manager = RecordingBackupManager(restoreFails: true)

        do {
            _ = try await fixture.execute(backupManager: manager)
            Issue.record("Expected restoration failure")
        } catch let error as SynchronizationTransactionError {
            guard case .restorationFailed(let failure) = error else {
                Issue.record("Unexpected transaction error: \(error)")
                return
            }
            #expect(failure.failedOperation?.logicalNodeID == transactionID(2))
            #expect(failure.appliedOperationCount == 1)
            #expect(failure.restorationStatus == .failed)
            #expect(failure.restorationFailure != nil)
        }

        #expect(manager.createCount == 1)
        #expect(manager.restoreCount == 1)
        #expect(try fixture.targetData() != fixture.originalData)
    }

    @Test("Residual diff after writes triggers byte-for-byte restoration")
    func residualDiffRestoration() async throws {
        let fixture = try TransactionFixture(operationCount: 2)
        defer { fixture.remove() }

        do {
            _ = try await fixture.execute(finalValidationFails: true)
            Issue.record("Expected final validation failure")
        } catch let error as SynchronizationTransactionError {
            guard case .finalValidationFailed(let failure) = error else {
                Issue.record("Unexpected transaction error: \(error)")
                return
            }
            #expect(failure.failedOperation == nil)
            #expect(failure.appliedOperationCount == 2)
            #expect(failure.restorationStatus == .succeeded)
        }

        #expect(try fixture.targetData() == fixture.originalData)
        #expect(try fixture.backupCount() == 1)
    }

    @Test("An empty plan performs no backup and no write")
    func emptyPlan() async throws {
        let fixture = try TransactionFixture(operationCount: 0)
        defer { fixture.remove() }

        let result = try await fixture.execute()

        #expect(result.appliedOperationCount == 0)
        #expect(result.backup == nil)
        #expect(result.restorationStatus == .notRequired)
        #expect(try fixture.backupCount() == 0)
        #expect(try fixture.targetData() == fixture.originalData)
    }

    @Test("Transaction models satisfy Sendable value semantics")
    func sendableModels() throws {
        let fixture = try TransactionFixture(operationCount: 1)
        defer { fixture.remove() }
        let backup = SynchronizationBackup(
            backupURL: fixture.backupDirectoryURL.appendingPathComponent("b"),
            targetURL: fixture.targetURL,
            createdAt: Date(timeIntervalSince1970: 1)
        )

        transactionRequireSendable(backup)
        #expect(Set([backup, backup]).count == 1)
    }

    @Test("Native identity additions are rolled back with the target file")
    func nativeRegistrationRollback() async throws {
        let fixture = try TransactionFixture(operationCount: 1)
        defer { fixture.remove() }
        let repository = InMemoryNativeIdentityRepository()
        let before = try repository.transactionSnapshot()
        let mapping = NativeIdentityMapping(
            logicalNodeID: transactionID(80),
            sourceID: BSESourceID(transactionUUID(280)),
            nativeIdentifier: NativeNodeIdentifier("native-created")
        )
        let coordinator = fixture.coordinator(participants: [
            NativeIdentitySynchronizationTransactionParticipant(
                repository: repository
            ),
        ])

        await #expect(throws: SynchronizationTransactionError.self) {
            _ = try await coordinator.execute { _, _ in
                repository.register(mapping)
                throw TransactionTestError.residualDiff
            }
        }

        #expect(try repository.transactionSnapshot() == before)
        #expect(try fixture.targetData() == fixture.originalData)
    }

    @Test("Native identity removals are rolled back with the target file")
    func nativeRemovalRollback() async throws {
        let fixture = try TransactionFixture(operationCount: 1)
        defer { fixture.remove() }
        let mapping = NativeIdentityMapping(
            logicalNodeID: transactionID(81),
            sourceID: BSESourceID(transactionUUID(281)),
            nativeIdentifier: NativeNodeIdentifier("native-deleted")
        )
        let repository = InMemoryNativeIdentityRepository(mappings: [mapping])
        let before = try repository.transactionSnapshot()
        let coordinator = fixture.coordinator(participants: [
            NativeIdentitySynchronizationTransactionParticipant(
                repository: repository
            ),
        ])

        await #expect(throws: SynchronizationTransactionError.self) {
            _ = try await coordinator.execute { _, _ in
                repository.remove(
                    logicalNodeID: mapping.logicalNodeID,
                    sourceID: mapping.sourceID
                )
                throw TransactionTestError.residualDiff
            }
        }

        #expect(try repository.transactionSnapshot() == before)
    }

    @Test("A Chrome native identity migration is rolled back exactly")
    func nativeMigrationRollback() async throws {
        let fixture = try TransactionFixture(operationCount: 1)
        defer { fixture.remove() }
        let logicalNodeID = transactionID(83)
        let sourceID = BSESourceID(transactionUUID(283))
        let fallback = NativeNodeIdentifier("id:42")
        let repository = InMemoryNativeIdentityRepository(mappings: [
            NativeIdentityMapping(
                logicalNodeID: logicalNodeID,
                sourceID: sourceID,
                nativeIdentifier: fallback
            ),
        ])
        let before = try repository.transactionSnapshot()
        let coordinator = fixture.coordinator(participants: [
            NativeIdentitySynchronizationTransactionParticipant(
                repository: repository
            ),
        ])

        await #expect(throws: SynchronizationTransactionError.self) {
            _ = try await coordinator.execute { _, _ in
                _ = try repository.applyAtomically([
                    .migrate(NativeIdentityMigration(
                        logicalNodeID: logicalNodeID,
                        sourceID: sourceID,
                        from: fallback,
                        fromKind: .chromeIDFallback,
                        to: NativeNodeIdentifier("guid:abc"),
                        toKind: .chromeGUID,
                        continuityProof: fallback,
                        continuityProofKind: .chromeIDFallback
                    )),
                ])
                throw TransactionTestError.residualDiff
            }
        }

        #expect(try repository.transactionSnapshot() == before)
        #expect(repository.nativeIdentifier(
            for: logicalNodeID,
            sourceID: sourceID
        ) == fallback)
        #expect(repository.logicalNodeID(
            for: NativeNodeIdentifier("guid:abc"),
            sourceID: sourceID
        ) == nil)
    }

    @Test("Preflight Baseline changes are inside the recovery boundary")
    func baselinePreflightRollback() async throws {
        let fixture = try TransactionFixture(operationCount: 1)
        defer { fixture.remove() }
        let original = try BaselineTestSupport.emptyBaseline()
        let store = InMemoryBaselineStore(baseline: original)
        let repository = BaselineRepository(store: store)
        let bodyCalled = Mutex(false)
        let coordinator = fixture.coordinator(participants: [
            BaselineSynchronizationTransactionParticipant(
                repository: repository
            ),
        ])

        await #expect(throws: TransactionTestError.self) {
            _ = try await coordinator.execute(preflight: {
                _ = try await repository.apply(
                    commands: [.createIdentity(CreateIdentityCommand(
                        logicalNodeID: transactionID(82),
                        observations: []
                    ))],
                    expectedRevision: original.revision
                )
                throw TransactionTestError.preflight
            }) { _, _ in
                bodyCalled.withLock { $0 = true }
            }
        }

        #expect(try await repository.load() == original)
        #expect(!bodyCalled.withLock { $0 })
        #expect(try fixture.backupCount() == 0)
    }

    @Test("Rollback failures identify every failed participant")
    func participantRollbackFailure() async throws {
        let fixture = try TransactionFixture(operationCount: 1)
        defer { fixture.remove() }
        let coordinator = fixture.coordinator(participants: [
            FailingTransactionParticipant(kind: .baseline),
            FailingTransactionParticipant(kind: .nativeIdentityRepository),
        ])

        do {
            _ = try await coordinator.execute { _, _ in
                throw TransactionTestError.residualDiff
            }
            Issue.record("Expected restoration failure")
        } catch let error as SynchronizationTransactionError {
            guard case .restorationFailed(let failure) = error else {
                Issue.record("Unexpected transaction error: \(error)")
                return
            }
            #expect(failure.restorationFailures.map(\.target) == [
                .participant(.nativeIdentityRepository),
                .participant(.baseline),
            ])
            #expect(failure.restorationStatus == .failed)
        }
    }

    @Test("Final validation failure restores every persistent participant")
    func finalValidationRestoresAllParticipants() async throws {
        let fixture = try TransactionFixture(operationCount: 1)
        defer { fixture.remove() }
        let originalBaseline = try BaselineTestSupport.emptyBaseline()
        let baselineStore = InMemoryBaselineStore(baseline: originalBaseline)
        let baselineRepository = BaselineRepository(store: baselineStore)
        let identityRepository = InMemoryNativeIdentityRepository()
        let identitySnapshot = try identityRepository.transactionSnapshot()
        let coordinator = fixture.coordinator(participants: [
            BaselineSynchronizationTransactionParticipant(
                repository: baselineRepository
            ),
            NativeIdentitySynchronizationTransactionParticipant(
                repository: identityRepository
            ),
        ])

        do {
            _ = try await coordinator.execute { executor, _ in
                _ = try await baselineRepository.apply(
                    commands: [.createIdentity(CreateIdentityCommand(
                        logicalNodeID: transactionID(84),
                        observations: []
                    ))],
                    expectedRevision: originalBaseline.revision
                )
                identityRepository.register(NativeIdentityMapping(
                    logicalNodeID: transactionID(84),
                    sourceID: BSESourceID(transactionUUID(284)),
                    nativeIdentifier: NativeNodeIdentifier("native-84")
                ))
                let execution = await executor.execute(
                    request: SynchronizationExecutionRequest(
                        plan: fixture.executionPlanForTest,
                        adapter: fixture.adapterForTest,
                        context: WriteExecutionContext(
                            sourceID: fixture.adapterForTest.sourceID,
                            mode: .apply
                        ),
                        policy: .stopOnFirstFailure
                    )
                )
                #expect(execution.status == .completed)
                throw TransactionTestError.residualDiff
            }
            Issue.record("Expected final validation failure")
        } catch let error as SynchronizationTransactionError {
            guard case .finalValidationFailed = error else {
                Issue.record("Unexpected transaction error: \(error)")
                return
            }
        }

        #expect(try fixture.targetData() == fixture.originalData)
        #expect(try await baselineRepository.load() == originalBaseline)
        #expect(
            try identityRepository.transactionSnapshot() == identitySnapshot
        )
    }
}

private final class TransactionFixture: Sendable {
    let rootURL: URL
    let targetURL: URL
    let backupDirectoryURL: URL
    let originalData = Data([0x42, 0x53, 0x45])

    private let plan: SynchronizationPlan
    private let confirmedPlan: ConfirmedSynchronizationPlan
    private let adapter: TransactionFileAdapter

    var executionPlanForTest: SynchronizationPlan { plan }
    var adapterForTest: TransactionFileAdapter { adapter }

    init(
        operationCount: Int,
        failingOperationIndex: Int? = nil
    ) throws {
        rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "BookmarkBridge-BSE792-\(UUID().uuidString)"
        )
        targetURL = rootURL.appendingPathComponent("Bookmarks")
        backupDirectoryURL = rootURL.appendingPathComponent("Backups")
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )
        try originalData.write(to: targetURL)

        let sourceID = BSESourceID(transactionUUID(200))
        let targetID = BSESourceID(transactionUUID(201))
        let operations = (0..<operationCount).map { index in
            SynchronizationOperation.rename(RenameNodeOperation(
                logicalNodeID: transactionID(index + 1),
                title: "Operation \(index + 1)"
            ))
        }
        plan = transactionPlan(
            operations: operations,
            sourceID: sourceID,
            targetID: targetID
        )
        let profile = try ChromeProfileIdentifier("Default")
        let request = ProductionSynchronizationRequest(
            direction: .safariToChrome,
            safariSourceID: sourceID,
            chromeSourceID: targetID,
            safariBookmarksURL: rootURL.appendingPathComponent("Safari"),
            chromeBookmarksURL: targetURL,
            safariBackupDirectoryURL:
                rootURL.appendingPathComponent("SafariBackups"),
            chromeBackupDirectoryURL: backupDirectoryURL,
            chromeProfileIdentifier: profile
        )
        confirmedPlan = ConfirmedSynchronizationPlan(
            direction: .safariToChrome,
            plan: plan,
            planFingerprint: SynchronizationPlanFingerprint(rawValue: "plan"),
            sourceSnapshotFingerprint:
                SynchronizationSnapshotFingerprint(rawValue: "source"),
            targetSnapshotFingerprint:
                SynchronizationSnapshotFingerprint(rawValue: "target"),
            executionRequest: request
        )
        adapter = TransactionFileAdapter(
            targetURL: targetURL,
            sourceID: targetID,
            failingOperationIndex: failingOperationIndex
        )
    }

    func coordinator(
        backupManager: any SynchronizationBackupManaging =
            FileSynchronizationBackupManager(
                dateProvider: { Date(timeIntervalSince1970: 1_800_000_000) },
                temporaryNameProvider: { "restore" }
            ),
        participants: [any SynchronizationTransactionParticipant] = []
    ) -> SynchronizationTransactionCoordinator {
        SynchronizationTransactionCoordinator(
            targetFileURL: targetURL,
            backupDirectoryURL: backupDirectoryURL,
            confirmedPlan: confirmedPlan,
            backupManager: backupManager,
            participants: participants
        )
    }

    func execute(
        backupManager: any SynchronizationBackupManaging =
            FileSynchronizationBackupManager(
                dateProvider: { Date(timeIntervalSince1970: 1_800_000_000) },
                temporaryNameProvider: { "restore" }
            ),
        finalValidationFails: Bool = false
    ) async throws -> SynchronizationTransactionResult {
        try await coordinator(backupManager: backupManager).execute {
            executor,
            _ in
            let execution = await executor.execute(
                request: SynchronizationExecutionRequest(
                    plan: self.plan,
                    adapter: self.adapter,
                    context: WriteExecutionContext(
                        sourceID: self.adapter.sourceID,
                        mode: .apply
                    ),
                    policy: .stopOnFirstFailure
                )
            )
            guard execution.status == .completed else {
                throw EndToEndSynchronizationError.executionFailed(
                    execution.status
                )
            }
            if finalValidationFails {
                throw TransactionTestError.residualDiff
            }
        }
    }

    func executionFailure() async -> SynchronizationTransactionFailure? {
        do {
            _ = try await execute()
            Issue.record("Expected execution failure")
            return nil
        } catch let error as SynchronizationTransactionError {
            guard case .executionFailed(let failure) = error else {
                Issue.record("Unexpected transaction error: \(error)")
                return nil
            }
            return failure
        } catch {
            Issue.record("Unexpected error: \(error)")
            return nil
        }
    }

    func targetData() throws -> Data {
        try Data(contentsOf: targetURL)
    }

    func backupData() throws -> Data {
        let urls = try FileManager.default.contentsOfDirectory(
            at: backupDirectoryURL,
            includingPropertiesForKeys: nil
        )
        return try Data(contentsOf: #require(urls.first))
    }

    func backupCount() throws -> Int {
        guard FileManager.default.fileExists(atPath: backupDirectoryURL.path) else {
            return 0
        }
        return try FileManager.default.contentsOfDirectory(
            at: backupDirectoryURL,
            includingPropertiesForKeys: nil
        ).count
    }

    func remove() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}

private final class TransactionFileAdapter: BookmarkWriteAdapter {
    let identifier = WriteAdapterIdentifier(transactionUUID(220))
    let capabilities = WriteAdapterCapabilities(
        canCreate: true,
        canDelete: true,
        canRename: true,
        canUpdateURL: true,
        canMove: true,
        canReorder: true,
        canArchive: true,
        canDryRun: true
    )
    let sourceID: BSESourceID

    private let targetURL: URL
    private let failingOperationIndex: Int?
    private let invocationCount = Mutex(0)

    init(
        targetURL: URL,
        sourceID: BSESourceID,
        failingOperationIndex: Int?
    ) {
        self.targetURL = targetURL
        self.sourceID = sourceID
        self.failingOperationIndex = failingOperationIndex
    }

    func execute(
        operation: SynchronizationOperation,
        context: WriteExecutionContext
    ) async throws -> WriteOperationResult {
        let index = invocationCount.withLock {
            let index = $0
            $0 += 1
            return index
        }
        if index == failingOperationIndex {
            throw WriteAdapterError.executionFailed(
                operation.writeOperationKind
            )
        }
        var data = try Data(contentsOf: targetURL)
        data.append(UInt8(truncatingIfNeeded: index + 1))
        try data.write(to: targetURL)
        return WriteOperationResult(
            adapterIdentifier: identifier,
            sourceID: sourceID,
            logicalNodeID: operation.logicalNodeID,
            status: .applied
        )
    }
}

private final class RecordingBackupManager: SynchronizationBackupManaging {
    private let createFails: Bool
    private let restoreFails: Bool
    private let storage = Mutex((create: 0, restore: 0))
    private let underlying = FileSynchronizationBackupManager(
        dateProvider: { Date(timeIntervalSince1970: 1_800_000_001) },
        temporaryNameProvider: { "recording-restore" }
    )

    init(createFails: Bool = false, restoreFails: Bool = false) {
        self.createFails = createFails
        self.restoreFails = restoreFails
    }

    var createCount: Int { storage.withLock { $0.create } }
    var restoreCount: Int { storage.withLock { $0.restore } }

    func createBackup(
        targetURL: URL,
        backupDirectoryURL: URL
    ) throws -> SynchronizationBackup {
        storage.withLock { $0.create += 1 }
        if createFails {
            throw TransactionTestError.backup
        }
        return try underlying.createBackup(
            targetURL: targetURL,
            backupDirectoryURL: backupDirectoryURL
        )
    }

    func restore(_ backup: SynchronizationBackup) throws {
        storage.withLock { $0.restore += 1 }
        if restoreFails {
            throw TransactionTestError.restore
        }
        try underlying.restore(backup)
    }
}

private enum TransactionTestError: Error {
    case backup
    case restore
    case residualDiff
    case preflight
}

private struct FailingTransactionParticipant:
    SynchronizationTransactionParticipant
{
    let kind: SynchronizationTransactionParticipantKind

    func capture() async throws -> SynchronizationTransactionCheckpoint {
        SynchronizationTransactionCheckpoint(kind: kind) {
            throw TransactionTestError.restore
        }
    }
}

private func transactionPlan(
    operations: [SynchronizationOperation],
    sourceID: BSESourceID,
    targetID: BSESourceID
) -> SynchronizationPlan {
    SynchronizationPlan(
        phases: [
            .preparation([]),
            .structural([]),
            .content(operations),
            .cleanup([]),
        ],
        report: SynchronizationPlanningReport(
            policy: .allChanges(direction: .oneWay(
                source: sourceID,
                target: targetID
            )),
            inputChangeCount: operations.count,
            plannedOperationCount: operations.count,
            skippedChangeCount: 0,
            preparationOperationCount: 0,
            structuralOperationCount: 0,
            contentOperationCount: operations.count,
            cleanupOperationCount: 0
        )
    )
}

private func transactionID(_ value: Int) -> LogicalNodeID {
    LogicalNodeID(transactionUUID(value))
}

private func transactionUUID(_ value: Int) -> UUID {
    UUID(uuid: (
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0,
        UInt8(truncatingIfNeeded: value >> 8),
        UInt8(truncatingIfNeeded: value)
    ))
}

private func transactionRequireSendable<T: Sendable>(_: T) {}
