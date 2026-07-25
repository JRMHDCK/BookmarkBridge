//
//  SynchronizationTransactionCoordinator.swift
//  BookmarkBridge
//

import Foundation
import Synchronization

/// Owns the joint recovery boundary around one complete BSE-760 pass.
/// The target file is restored first, followed by durable BSE participants in
/// reverse capture order. Successful final validation commits by releasing
/// every immutable recovery point.
nonisolated struct SynchronizationTransactionCoordinator: Sendable {
    private let targetFileURL: URL
    private let backupDirectoryURL: URL
    private let confirmedPlan: ConfirmedSynchronizationPlan
    private let executor: any EndToEndSynchronizationExecuting
    private let backupManager: any SynchronizationBackupManaging
    private let participants: [any SynchronizationTransactionParticipant]

    init(
        targetFileURL: URL,
        backupDirectoryURL: URL,
        confirmedPlan: ConfirmedSynchronizationPlan,
        executor: any EndToEndSynchronizationExecuting =
            SynchronizationExecutor(),
        backupManager: any SynchronizationBackupManaging =
            FileSynchronizationBackupManager(),
        participants: [any SynchronizationTransactionParticipant] = []
    ) {
        self.targetFileURL = targetFileURL
        self.backupDirectoryURL = backupDirectoryURL
        self.confirmedPlan = confirmedPlan
        self.executor = executor
        self.backupManager = backupManager
        self.participants = participants
    }

    func execute(
        preflight: @Sendable () async throws -> Void = {},
        _ body: @Sendable (
            any EndToEndSynchronizationExecuting,
            SynchronizationBackup?
        ) async throws -> Void
    ) async throws -> SynchronizationTransactionResult {
        var checkpoints: [SynchronizationTransactionCheckpoint] = []
        for participant in participants {
            do {
                checkpoints.append(try await participant.capture())
            } catch {
                let failures = await rollback(
                    backup: nil,
                    checkpoints: checkpoints
                )
                guard failures.isEmpty else {
                    throw restorationError(
                        after: error,
                        execution: nil,
                        failures: failures
                    )
                }
                throw SynchronizationTransactionError.participantCaptureFailed(
                    participant.kind,
                    SynchronizationTransactionFailureContext(error)
                )
            }
        }

        do {
            try await preflight()
        } catch {
            let failures = await rollback(
                backup: nil,
                checkpoints: checkpoints
            )
            guard failures.isEmpty else {
                throw restorationError(
                    after: error,
                    execution: nil,
                    failures: failures
                )
            }
            throw error
        }

        let backup: SynchronizationBackup?
        if confirmedPlan.plan.operations.isEmpty {
            backup = nil
        } else {
            do {
                backup = try backupManager.createBackup(
                    targetURL: targetFileURL,
                    backupDirectoryURL: backupDirectoryURL
                )
            } catch {
                let failures = await rollback(
                    backup: nil,
                    checkpoints: checkpoints
                )
                guard failures.isEmpty else {
                    throw restorationError(
                        after: error,
                        execution: nil,
                        failures: failures
                    )
                }
                throw SynchronizationTransactionError.backupCreationFailed(
                    SynchronizationTransactionFailureContext(error)
                )
            }
        }

        let recorder = SynchronizationExecutionRecorder(executor: executor)
        do {
            try await body(recorder, backup)
            let appliedCount = recorder.result?.report.appliedOperationCount ?? 0
            return SynchronizationTransactionResult(
                appliedOperationCount: appliedCount,
                backup: backup,
                restorationStatus: .notRequired
            )
        } catch {
            let failures = await rollback(
                backup: backup,
                checkpoints: checkpoints
            )
            if backup == nil, failures.isEmpty {
                throw error
            }
            throw recoveryError(
                after: error,
                execution: recorder.result,
                failures: failures
            )
        }
    }

    private func recoveryError(
        after error: any Error,
        execution: SynchronizationExecutionResult?,
        failures: [SynchronizationTransactionRestorationFailure]
    ) -> SynchronizationTransactionError {
        let failedOperation = execution?.operationResults.first {
            $0.status == .failed
                || $0.status == .refused
                || $0.status == .cancelled
        }?.operation
        let appliedCount = execution?.report.appliedOperationCount ?? 0
        let isFinalValidationFailure = execution?.status == .completed
        let failure = SynchronizationTransactionFailure(
            failedOperation: failedOperation,
            appliedOperationCount: appliedCount,
            restorationStatus: failures.isEmpty ? .succeeded : .failed,
            cause: SynchronizationTransactionFailureContext(error),
            restorationFailures: failures
        )
        guard failures.isEmpty else {
            return .restorationFailed(failure)
        }
        return isFinalValidationFailure
            ? .finalValidationFailed(failure)
            : .executionFailed(failure)
    }

    private func restorationError(
        after error: any Error,
        execution: SynchronizationExecutionResult?,
        failures: [SynchronizationTransactionRestorationFailure]
    ) -> SynchronizationTransactionError {
        .restorationFailed(SynchronizationTransactionFailure(
            failedOperation: execution?.operationResults.first {
                $0.status == .failed
                    || $0.status == .refused
                    || $0.status == .cancelled
            }?.operation,
            appliedOperationCount:
                execution?.report.appliedOperationCount ?? 0,
            restorationStatus: .failed,
            cause: SynchronizationTransactionFailureContext(error),
            restorationFailures: failures
        ))
    }

    /// File restoration runs first because it is the last durable boundary
    /// captured. Repository checkpoints then unwind in reverse capture order.
    private func rollback(
        backup: SynchronizationBackup?,
        checkpoints: [SynchronizationTransactionCheckpoint]
    ) async -> [SynchronizationTransactionRestorationFailure] {
        var failures: [SynchronizationTransactionRestorationFailure] = []
        if let backup {
            do {
                try backupManager.restore(backup)
            } catch {
                failures.append(SynchronizationTransactionRestorationFailure(
                    target: .targetFile,
                    context: SynchronizationTransactionFailureContext(error)
                ))
            }
        }
        for checkpoint in checkpoints.reversed() {
            do {
                try await checkpoint.rollback()
            } catch {
                failures.append(SynchronizationTransactionRestorationFailure(
                    target: .participant(checkpoint.kind),
                    context: SynchronizationTransactionFailureContext(error)
                ))
            }
        }
        return failures
    }
}

nonisolated private final class SynchronizationExecutionRecorder:
    EndToEndSynchronizationExecuting
{
    private let executor: any EndToEndSynchronizationExecuting
    private let storage = Mutex<SynchronizationExecutionResult?>(nil)

    init(executor: any EndToEndSynchronizationExecuting) {
        self.executor = executor
    }

    var result: SynchronizationExecutionResult? {
        storage.withLock { $0 }
    }

    func execute(
        request: SynchronizationExecutionRequest
    ) async -> SynchronizationExecutionResult {
        let result = await executor.execute(request: request)
        storage.withLock { $0 = result }
        return result
    }
}
