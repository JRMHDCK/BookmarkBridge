//
//  ProductionSynchronizationService.swift
//  BookmarkBridge
//

import Foundation
import Synchronization

/// Composition root for one real, explicitly directed browser synchronization.
/// All matching, mutation, persistence, planning, and execution behavior stays
/// in the injected or concrete components that already own it.
///
/// The injected Baseline and native identity repositories are durable
/// transaction participants shared by preview, execution, and verification.
nonisolated struct ProductionSynchronizationService: Sendable {
    private let baselineRepository: BaselineRepository
    private let identityProvider: any IdentityProvider
    private let nativeIdentityRepository: any NativeIdentityRepository
    private let nativeIdentifierProvider: any NativeIdentifierProviding
    private let safariApplicationStateChecker:
        any SafariApplicationStateChecking
    private let chromeApplicationStateChecker:
        any ChromeApplicationStateChecking
    private let safariAdapterIdentifier: WriteAdapterIdentifier
    private let chromeAdapterIdentifier: WriteAdapterIdentifier
    private let sessionCoordinator:
        ProductionSynchronizationSessionCoordinator
    private let fileController: any SecurityScopedFileControlling

    init(
        baselineRepository: BaselineRepository,
        identityProvider: any IdentityProvider,
        nativeIdentityRepository: any NativeIdentityRepository,
        nativeIdentifierProvider: any NativeIdentifierProviding =
            UUIDNativeIdentifierProvider(),
        safariApplicationStateChecker:
            any SafariApplicationStateChecking =
                SafariApplicationStateChecker(),
        chromeApplicationStateChecker:
            any ChromeApplicationStateChecking =
                ChromeApplicationStateChecker(),
        safariAdapterIdentifier: WriteAdapterIdentifier,
        chromeAdapterIdentifier: WriteAdapterIdentifier,
        sessionCoordinator: ProductionSynchronizationSessionCoordinator =
            ProductionSynchronizationSessionCoordinator(),
        fileController: any SecurityScopedFileControlling =
            SystemSecurityScopedFileController()
    ) {
        self.baselineRepository = baselineRepository
        self.identityProvider = identityProvider
        self.nativeIdentityRepository = nativeIdentityRepository
        self.nativeIdentifierProvider = nativeIdentifierProvider
        self.safariApplicationStateChecker = safariApplicationStateChecker
        self.chromeApplicationStateChecker = chromeApplicationStateChecker
        self.safariAdapterIdentifier = safariAdapterIdentifier
        self.chromeAdapterIdentifier = chromeAdapterIdentifier
        self.sessionCoordinator = sessionCoordinator
        self.fileController = fileController
    }

    func synchronize(
        confirmedPlan: ConfirmedSynchronizationPlan
    ) async throws -> ProductionSynchronizationResult {
        try await sessionCoordinator.withSession {
            try await performSynchronization(confirmedPlan: confirmedPlan)
        }
    }

    private func performSynchronization(
        confirmedPlan: ConfirmedSynchronizationPlan
    ) async throws -> ProductionSynchronizationResult {
        let request = confirmedPlan.executionRequest
        let safariAccess = fileController.startAccessing(
            request.safariSecurityScopeURL
        )
        let chromeAccess = fileController.startAccessing(
            request.chromeSecurityScopeURL
        )
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

        var executionPlanValidation: ExecutionPlanValidation?
        do {
            let direction: SynchronizationDirection
            switch request.direction {
            case .safariToChrome:
                direction = .oneWay(
                    source: request.safariSourceID,
                    target: request.chromeSourceID
                )
            case .chromeToSafari:
                direction = .oneWay(
                    source: request.chromeSourceID,
                    target: request.safariSourceID
                )
            }

            let validation = ExecutionPlanValidation()
            executionPlanValidation = validation
            let target = transactionTarget(for: request)
            let coordinator = SynchronizationTransactionCoordinator(
                targetFileURL: target.fileURL,
                backupDirectoryURL: target.backupDirectoryURL,
                confirmedPlan: confirmedPlan,
                backupManager: transactionBackupManager(for: request),
                participants: [
                    BaselineSynchronizationTransactionParticipant(
                        repository: baselineRepository
                    ),
                    NativeIdentitySynchronizationTransactionParticipant(
                        repository: nativeIdentityRepository
                    ),
                ]
            )
            let synchronizationStorage =
                Mutex<EndToEndSynchronizationResult?>(nil)
            let transaction = try await coordinator.execute(preflight: {
                try safariApplicationStateChecker.ensureSafariIsClosed()
                try chromeApplicationStateChecker.ensureChromeIsClosed()
                let preview = try await SynchronizationPreviewService(
                    baselineRepository: baselineRepository,
                    identityProvider: identityProvider,
                    nativeIdentityRepository: nativeIdentityRepository
                ).preview(request: previewRequest(for: request))
                try confirmedPlan.validate(against: preview)
            }) {
                transactionExecutor,
                backup in
                let components = makeComponents(
                    request: request,
                    transactionBackup: backup
                )
                let confirmedPlanner = ConfirmedExecutionPlanner(
                    confirmedPlan: confirmedPlan,
                    validation: validation
                )
                let pipeline: EndToEndSynchronizationPipeline
                switch request.direction {
                case .safariToChrome:
                    pipeline = EndToEndSynchronizationPipeline(
                        sourceReader: components.safariReader,
                        targetReader: components.chromeReader,
                        matchingPipeline: components.matchingPipeline,
                        identityResolver: NativeIdentityResolver(
                            repository: nativeIdentityRepository
                        ),
                        bootstrapper: components.bootstrapper,
                        planner: confirmedPlanner,
                        executor: transactionExecutor,
                        writeAdapter: components.chromeWriter
                    )
                case .chromeToSafari:
                    pipeline = EndToEndSynchronizationPipeline(
                        sourceReader: components.chromeReader,
                        targetReader: components.safariReader,
                        matchingPipeline: components.matchingPipeline,
                        identityResolver: NativeIdentityResolver(
                            repository: nativeIdentityRepository
                        ),
                        bootstrapper: components.bootstrapper,
                        planner: confirmedPlanner,
                        executor: transactionExecutor,
                        writeAdapter: components.safariWriter
                    )
                }

                let synchronization = try await pipeline.execute(
                    request: EndToEndSynchronizationRequest(
                        synchronizationPolicy: .allChanges(
                            direction: direction
                        ),
                        writeContext: WriteExecutionContext(
                            sourceID: direction.target,
                            mode: .apply
                        ),
                        executionPolicy: .stopOnFirstFailure
                    )
                )
                synchronizationStorage.withLock {
                    $0 = synchronization
                }
            }
            guard let synchronization = synchronizationStorage.withLock({
                $0
            }) else {
                throw ProductionSynchronizationError.synchronizationFailed(
                    ProductionSynchronizationFailureContext(
                        MissingTransactionSynchronizationResult()
                    )
                )
            }
            return ProductionSynchronizationResult(
                direction: request.direction,
                synchronization: synchronization,
                transaction: transaction
            )
        } catch let error as PlanConfirmationError {
            throw error
        } catch let error as SynchronizationTransactionError {
            throw error
        } catch {
            if executionPlanValidation?.planChanged == true {
                throw PlanConfirmationError.planChanged
            }
            throw ProductionSynchronizationError.synchronizationFailed(
                ProductionSynchronizationFailureContext(error)
            )
        }
    }

    private func makeComponents(
        request: ProductionSynchronizationRequest,
        transactionBackup: SynchronizationBackup?
    ) -> Components {
        let safariAdapter = SafariAdapter(
            sourceID: request.safariSourceID,
            dataSource: DefaultSafariDataSource(
                bookmarksFileURL: request.safariBookmarksURL
            )
        )
        let chromeAdapter = ChromeAdapter(
            sourceID: request.chromeSourceID,
            profileIdentifier: request.chromeProfileIdentifier,
            dataSource: DefaultChromeDataSource(
                bookmarksFileURL: request.chromeBookmarksURL,
                profileIdentifier: request.chromeProfileIdentifier,
                securityScopeURL: request.chromeSecurityScopeURL
            )
        )
        let safariReader = SelectionScopedSynchronizationReader(
            reader: safariAdapter,
            selection: request.safariSelection
        )
        let chromeReader = SelectionScopedSynchronizationReader(
            reader: chromeAdapter,
            selection: request.chromeSelection
        )

        let safariBackupService: any SafariBookmarkBackingUp
        let chromeBackupService: any ChromeBookmarkBackingUp
        if let transactionBackup {
            safariBackupService = TransactionSafariBackupRelay(
                backup: transactionBackup
            )
            chromeBackupService = TransactionChromeBackupRelay(
                backup: transactionBackup
            )
        } else {
            safariBackupService = SafariBookmarkBackupService(
                backupDirectoryURL: request.safariBackupDirectoryURL
            )
            chromeBackupService = ChromeBookmarkBackupService(
                backupDirectoryURL: request.chromeBackupDirectoryURL
            )
        }

        let safariStore = SafariBookmarkStore(
            bookmarksFileURL: request.safariBookmarksURL,
            validator: SafariBookmarkValidator(),
            backupService: safariBackupService,
            atomicWriter: SafariAtomicWriter(),
            applicationStateChecker: safariApplicationStateChecker
        )
        let chromeStore = ChromeBookmarkStore(
            bookmarksFileURL: request.chromeBookmarksURL,
            validator: ChromeBookmarkValidator(),
            backupService: chromeBackupService,
            atomicWriter: ChromeAtomicWriter(),
            applicationStateChecker: chromeApplicationStateChecker
        )

        let safariMutator = SafariBookmarkMutator(
            sourceID: request.safariSourceID,
            nativeIdentityRepository: nativeIdentityRepository,
            nativeIdentifierProvider: nativeIdentifierProvider
        )
        let chromeMutator = ChromeBookmarkMutator(
            sourceID: request.chromeSourceID,
            nativeIdentityRepository: nativeIdentityRepository,
            nativeIdentifierProvider: nativeIdentifierProvider
        )
        let safariWriter = SafariBookmarkWriteAdapter(
            identifier: safariAdapterIdentifier,
            sourceID: request.safariSourceID,
            store: safariStore,
            mutator: SafariWriter(mutator: safariMutator),
            nativeIdentityRepository: nativeIdentityRepository
        )
        let chromeWriter = ChromeBookmarkWriteAdapter(
            identifier: chromeAdapterIdentifier,
            sourceID: request.chromeSourceID,
            store: chromeStore,
            mutator: chromeMutator,
            nativeIdentityRepository: nativeIdentityRepository
        )
        let reconciliation = IdentityReconciliationEngine(
            identityProvider: identityProvider,
            matchingPolicy: StrictIdentityMatchingPolicy(),
            snapshotBuilder: LogicalSnapshotBuilder()
        )
        let matchingPipeline = MatchingPipeline(
            baselineRepository: baselineRepository,
            matchingEngine: MatchingEngine(),
            groupBuilder: DefaultIdentityMatchingGroupBuilder(),
            reconciliationEngine: reconciliation
        )
        return Components(
            safariReader: safariReader,
            chromeReader: chromeReader,
            safariWriter: safariWriter,
            chromeWriter: chromeWriter,
            matchingPipeline: matchingPipeline,
            bootstrapper: NativeIdentityBootstrapper(
                repository: nativeIdentityRepository
            )
        )
    }

    private func previewRequest(
        for request: ProductionSynchronizationRequest
    ) -> SynchronizationPreviewRequest {
        SynchronizationPreviewRequest(
            direction: request.direction,
            safariSourceID: request.safariSourceID,
            chromeSourceID: request.chromeSourceID,
            safariBookmarksURL: request.safariBookmarksURL,
            chromeBookmarksURL: request.chromeBookmarksURL,
            chromeProfileIdentifier: request.chromeProfileIdentifier,
            safariSecurityScopeURL: request.safariSecurityScopeURL,
            chromeSecurityScopeURL: request.chromeSecurityScopeURL,
            safariSelection: request.safariSelection,
            chromeSelection: request.chromeSelection
        )
    }

    private func transactionTarget(
        for request: ProductionSynchronizationRequest
    ) -> (fileURL: URL, backupDirectoryURL: URL) {
        switch request.direction {
        case .safariToChrome:
            (
                request.chromeBookmarksURL,
                request.chromeBackupDirectoryURL
            )
        case .chromeToSafari:
            (
                request.safariBookmarksURL,
                request.safariBackupDirectoryURL
            )
        }
    }

    private func transactionBackupManager(
        for request: ProductionSynchronizationRequest
    ) -> any SynchronizationBackupManaging {
        let readinessCheck: @Sendable () throws -> Void
        switch request.direction {
        case .safariToChrome:
            readinessCheck = {
                try chromeApplicationStateChecker.ensureChromeIsClosed()
            }
        case .chromeToSafari:
            readinessCheck = {
                try safariApplicationStateChecker.ensureSafariIsClosed()
            }
        }
        return GuardedTransactionBackupManager(
            underlying: FileSynchronizationBackupManager(),
            restorationReadinessCheck: readinessCheck
        )
    }

    private struct Components {
        let safariReader: SelectionScopedSynchronizationReader
        let chromeReader: SelectionScopedSynchronizationReader
        let safariWriter: SafariBookmarkWriteAdapter
        let chromeWriter: ChromeBookmarkWriteAdapter
        let matchingPipeline: MatchingPipeline
        let bootstrapper: NativeIdentityBootstrapper
    }
}

nonisolated private struct MissingTransactionSynchronizationResult: Error {}

nonisolated private struct TransactionSafariBackupRelay:
    SafariBookmarkBackingUp
{
    let backup: SynchronizationBackup

    func createBackup(of sourceURL: URL) throws -> URL {
        guard sourceURL.standardizedFileURL == backup.targetURL.standardizedFileURL else {
            throw SafariPersistenceError.backupFailed
        }
        return backup.backupURL
    }
}

nonisolated private struct TransactionChromeBackupRelay:
    ChromeBookmarkBackingUp
{
    let backup: SynchronizationBackup

    func createBackup(of sourceURL: URL) throws -> URL {
        guard sourceURL.standardizedFileURL == backup.targetURL.standardizedFileURL else {
            throw ChromePersistenceError.backupFailed
        }
        return backup.backupURL
    }
}

nonisolated private struct GuardedTransactionBackupManager:
    SynchronizationBackupManaging
{
    let underlying: any SynchronizationBackupManaging
    let restorationReadinessCheck: @Sendable () throws -> Void

    func createBackup(
        targetURL: URL,
        backupDirectoryURL: URL
    ) throws -> SynchronizationBackup {
        try underlying.createBackup(
            targetURL: targetURL,
            backupDirectoryURL: backupDirectoryURL
        )
    }

    func restore(_ backup: SynchronizationBackup) throws {
        let backupData = try Data(contentsOf: backup.backupURL)
        let currentData = try Data(contentsOf: backup.targetURL)
        if currentData == backupData {
            return
        }
        try restorationReadinessCheck()
        try underlying.restore(backup)
    }
}

nonisolated private final class ExecutionPlanValidation: Sendable {
    private let storage = Mutex(false)

    var planChanged: Bool {
        storage.withLock { $0 }
    }

    func markPlanChanged() {
        storage.withLock { $0 = true }
    }
}

nonisolated private struct ConfirmedExecutionPlanner:
    EndToEndSynchronizationPlanning
{
    let confirmedPlan: ConfirmedSynchronizationPlan
    let validation: ExecutionPlanValidation

    func plan(
        request: SynchronizationPlanningRequest
    ) throws -> SynchronizationPlan {
        let reconstructed = try SynchronizationPlanner().plan(request: request)
        guard reconstructed == confirmedPlan.plan,
              try PlanConfirmationFingerprinting.plan(reconstructed)
                == confirmedPlan.planFingerprint else {
            validation.markPlanChanged()
            throw PlanConfirmationError.planChanged
        }
        return confirmedPlan.plan
    }
}
