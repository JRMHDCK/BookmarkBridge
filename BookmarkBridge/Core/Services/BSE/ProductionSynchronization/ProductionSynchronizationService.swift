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
    private let chromeAdapterIdentifier: WriteAdapterIdentifier
    private let sessionCoordinator:
        ProductionSynchronizationSessionCoordinator
    private let fileController: any SecurityScopedFileControlling
    private let diagnosticRecorder: (any DiagnosticEventRecording)?
    private let nowProvider: @Sendable () -> Date

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
        chromeAdapterIdentifier: WriteAdapterIdentifier,
        sessionCoordinator: ProductionSynchronizationSessionCoordinator =
            ProductionSynchronizationSessionCoordinator(),
        fileController: any SecurityScopedFileControlling =
            SystemSecurityScopedFileController(),
        diagnosticRecorder: (any DiagnosticEventRecording)? = nil,
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.baselineRepository = baselineRepository
        self.identityProvider = identityProvider
        self.nativeIdentityRepository = nativeIdentityRepository
        self.nativeIdentifierProvider = nativeIdentifierProvider
        self.safariApplicationStateChecker = safariApplicationStateChecker
        self.chromeApplicationStateChecker = chromeApplicationStateChecker
        self.chromeAdapterIdentifier = chromeAdapterIdentifier
        self.sessionCoordinator = sessionCoordinator
        self.fileController = fileController
        self.diagnosticRecorder = diagnosticRecorder
        self.nowProvider = nowProvider
    }

    func synchronize(
        confirmedPlan: ConfirmedSynchronizationPlan
    ) async throws -> ProductionSynchronizationResult {
        let request = confirmedPlan.executionRequest
        let direction = diagnosticDirection(request.direction)
        let changeCount = confirmedPlan.plan.operations.count
        let startedAt = nowProvider()
        let initialFileEvidence = safariFileEvidence(
            at: request.safariBookmarksURL
        )
        await recordDiagnosticEvent(DiagnosticEvent(
            timestamp: startedAt,
            level: .information,
            component: .synchronization,
            stage: .planning,
            outcome: .started,
            direction: direction,
            counts: DiagnosticCounts(changes: changeCount),
            fileEvidence: initialFileEvidence
        ))

        do {
            let result = try await sessionCoordinator.withSession {
                try await performSynchronization(confirmedPlan: confirmedPlan)
            }
            await recordDiagnosticEvent(DiagnosticEvent(
                timestamp: nowProvider(),
                level: .information,
                component: .synchronization,
                stage: .validation,
                outcome: .succeeded,
                direction: direction,
                durationMilliseconds: durationSince(startedAt),
                counts: DiagnosticCounts(changes: changeCount),
                fileEvidence: safariFileEvidence(
                    at: request.safariBookmarksURL
                )
            ))
            return result
        } catch is CancellationError {
            await recordDiagnosticEvent(DiagnosticEvent(
                timestamp: nowProvider(),
                level: .warning,
                component: .synchronization,
                stage: .unknown,
                outcome: .cancelled,
                direction: direction,
                durationMilliseconds: durationSince(startedAt),
                counts: DiagnosticCounts(changes: changeCount),
                fileEvidence: safariFileEvidence(
                    at: request.safariBookmarksURL
                )
            ))
            throw CancellationError()
        } catch {
            let failure = diagnosticFailure(for: error)
            await recordDiagnosticEvent(DiagnosticEvent(
                timestamp: nowProvider(),
                level: .error,
                component: .synchronization,
                stage: failure.stage,
                outcome: .failed,
                direction: direction,
                errorType: failure.errorType,
                errorCode: failure.errorCode,
                durationMilliseconds: durationSince(startedAt),
                counts: DiagnosticCounts(changes: changeCount),
                fileEvidence: safariFileEvidence(
                    at: request.safariBookmarksURL
                )
            ))
            throw error
        }
    }

    private func performSynchronization(
        confirmedPlan: ConfirmedSynchronizationPlan
    ) async throws -> ProductionSynchronizationResult {
        let request = confirmedPlan.executionRequest
        guard request.direction == .safariToChrome else {
            throw ProductionSynchronizationError.unsupportedDirection(
                request.direction
            )
        }
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
            let direction = SynchronizationDirection.oneWay(
                source: request.safariSourceID,
                target: request.chromeSourceID
            )

            let validation = ExecutionPlanValidation()
            executionPlanValidation = validation
            let coordinator = SynchronizationTransactionCoordinator(
                targetFileURL: request.chromeBookmarksURL,
                backupDirectoryURL: request.chromeBackupDirectoryURL,
                confirmedPlan: confirmedPlan,
                backupManager: transactionBackupManager(),
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
            await recordDiagnosticEvent(DiagnosticEvent(
                timestamp: nowProvider(),
                level: .information,
                component: .backup,
                stage: .backup,
                outcome: .started,
                direction: diagnosticDirection(request.direction),
                counts: DiagnosticCounts(
                    changes: confirmedPlan.plan.operations.count
                ),
                fileEvidence: safariFileEvidence(
                    at: request.safariBookmarksURL
                )
            ))
            let transaction = try await coordinator.execute(preflight: {
                try safariApplicationStateChecker.ensureSafariIsClosed()
                try chromeApplicationStateChecker.ensureChromeIsClosed()
                let preview = try await SynchronizationPreviewService(
                    baselineRepository: baselineRepository,
                    identityProvider: identityProvider,
                    nativeIdentityRepository: nativeIdentityRepository
                ).preview(request: previewRequest(for: request))
                try confirmedPlan.validate(against: preview)
                await recordDiagnosticEvent(DiagnosticEvent(
                    timestamp: nowProvider(),
                    level: .information,
                    component: .synchronization,
                    stage: .planning,
                    outcome: .succeeded,
                    direction: diagnosticDirection(request.direction),
                    counts: DiagnosticCounts(
                        changes: confirmedPlan.plan.operations.count
                    ),
                    fileEvidence: safariFileEvidence(
                        at: request.safariBookmarksURL
                    )
                ))
            }) {
                transactionExecutor,
                backup in
                await recordDiagnosticEvent(DiagnosticEvent(
                    timestamp: nowProvider(),
                    level: .information,
                    component: .backup,
                    stage: .backup,
                    outcome: .succeeded,
                    direction: diagnosticDirection(request.direction),
                    counts: DiagnosticCounts(
                        changes: confirmedPlan.plan.operations.count
                    ),
                    fileEvidence: safariFileEvidence(
                        at: request.safariBookmarksURL
                    )
                ))
                let components = makeComponents(
                    request: request,
                    transactionBackup: backup
                )
                let confirmedPlanner = ConfirmedExecutionPlanner(
                    confirmedPlan: confirmedPlan,
                    validation: validation
                )
                let pipeline = EndToEndSynchronizationPipeline(
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

                await recordDiagnosticEvent(DiagnosticEvent(
                    timestamp: nowProvider(),
                    level: .information,
                    component: .writer,
                    stage: .writing,
                    outcome: .started,
                    direction: diagnosticDirection(request.direction),
                    counts: DiagnosticCounts(
                        changes: confirmedPlan.plan.operations.count
                    ),
                    fileEvidence: safariFileEvidence(
                        at: request.safariBookmarksURL
                    )
                ))
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
                await recordDiagnosticEvent(DiagnosticEvent(
                    timestamp: nowProvider(),
                    level: .information,
                    component: .writer,
                    stage: .writing,
                    outcome: .succeeded,
                    direction: diagnosticDirection(request.direction),
                    counts: DiagnosticCounts(
                        changes: synchronization.execution.report
                            .appliedOperationCount
                    ),
                    fileEvidence: safariFileEvidence(
                        at: request.safariBookmarksURL
                    )
                ))
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

        let chromeBackupService: any ChromeBookmarkBackingUp
        if let transactionBackup {
            chromeBackupService = TransactionChromeBackupRelay(
                backup: transactionBackup
            )
        } else {
            chromeBackupService = ChromeBookmarkBackupService(
                backupDirectoryURL: request.chromeBackupDirectoryURL
            )
        }

        let chromeStore = ChromeBookmarkStore(
            bookmarksFileURL: request.chromeBookmarksURL,
            validator: ChromeBookmarkValidator(),
            backupService: chromeBackupService,
            atomicWriter: ChromeAtomicWriter(),
            applicationStateChecker: chromeApplicationStateChecker
        )

        let chromeMutator = ChromeBookmarkMutator(
            sourceID: request.chromeSourceID,
            nativeIdentityRepository: nativeIdentityRepository,
            nativeIdentifierProvider: nativeIdentifierProvider
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
            // Execution and final verification must preserve the exact
            // duplicate identities established by the confirmed preview.
            groupBuilder:
                SynchronizationDuplicateIdentityMatchingGroupBuilder(),
            reconciliationEngine: reconciliation
        )
        return Components(
            safariReader: safariReader,
            chromeReader: chromeReader,
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

    private func transactionBackupManager(
    ) -> any SynchronizationBackupManaging {
        return GuardedTransactionBackupManager(
            underlying: FileSynchronizationBackupManager(),
            restorationReadinessCheck: {
                try chromeApplicationStateChecker.ensureChromeIsClosed()
            }
        )
    }

    private func recordDiagnosticEvent(_ event: DiagnosticEvent) async {
        guard let diagnosticRecorder else { return }
        try? await diagnosticRecorder.record(event, now: event.timestamp)
    }

    private func durationSince(_ start: Date) -> UInt64? {
        let milliseconds = nowProvider().timeIntervalSince(start) * 1_000
        guard milliseconds.isFinite else { return nil }
        return UInt64(min(max(0, milliseconds), Double(Int.max)))
    }

    private func diagnosticDirection(
        _ direction: ProductionSynchronizationDirection
    ) -> DiagnosticSynchronizationDirection {
        switch direction {
        case .safariToChrome: .safariToChrome
        case .chromeToSafari: .chromeToSafari
        }
    }

    private func safariFileEvidence(
        at fileURL: URL
    ) -> DiagnosticFileEvidence? {
        guard let fingerprint = try? DiagnosticFileFingerprint.capture(
            at: fileURL
        ) else {
            return nil
        }
        let canonicalURL = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library", directoryHint: .isDirectory)
            .appending(path: "Safari", directoryHint: .isDirectory)
            .appending(path: "Bookmarks.plist", directoryHint: .notDirectory)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        let resolvedURL = fileURL.standardizedFileURL.resolvingSymlinksInPath()
        return DiagnosticFileEvidence(
            location: resolvedURL == canonicalURL
                ? .canonicalBookmarks
                : .alternateBookmarks,
            fileSize: fingerprint.fileSize,
            modificationDate: fingerprint.modificationDate,
            sha256: fingerprint.contentDigest,
            fileSystemNumber: fingerprint.fileSystemNumber,
            inode: fingerprint.fileNumber
        )
    }

    private func diagnosticFailure(
        for error: any Error
    ) -> (
        stage: DiagnosticStage,
        errorType: DiagnosticErrorType,
        errorCode: DiagnosticErrorCode
    ) {
        if error is PlanConfirmationError {
            return (.planning, .planning, .validationFailed)
        }
        guard let transactionError = error as? SynchronizationTransactionError else {
            return (.unknown, .synchronization, .unknown)
        }
        switch transactionError {
        case .backupCreationFailed, .participantCaptureFailed:
            return (.backup, .backup, .backupFailed)
        case .executionFailed:
            return (.writing, .writing, .transactionFailed)
        case .finalValidationFailed:
            return (.validation, .validation, .validationFailed)
        case .restorationFailed:
            return (.restoration, .restoration, .restorationFailed)
        }
    }

    private struct Components {
        let safariReader: SelectionScopedSynchronizationReader
        let chromeReader: SelectionScopedSynchronizationReader
        let chromeWriter: ChromeBookmarkWriteAdapter
        let matchingPipeline: MatchingPipeline
        let bootstrapper: NativeIdentityBootstrapper
    }
}

nonisolated private struct MissingTransactionSynchronizationResult: Error {}

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
