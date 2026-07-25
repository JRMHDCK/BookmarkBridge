//
//  SynchronizationTransactionError.swift
//  BookmarkBridge
//

nonisolated struct SynchronizationTransactionFailureContext:
    Hashable,
    Sendable
{
    let errorType: String
    let description: String

    init(_ error: any Error) {
        errorType = String(reflecting: type(of: error))
        description = String(describing: error)
    }
}

nonisolated struct SynchronizationTransactionFailure: Hashable, Sendable {
    let failedOperation: SynchronizationOperation?
    let appliedOperationCount: Int
    let restorationStatus: SynchronizationRestorationStatus
    let cause: SynchronizationTransactionFailureContext
    let restorationFailures: [SynchronizationTransactionRestorationFailure]

    var restorationFailure: SynchronizationTransactionFailureContext? {
        restorationFailures.first?.context
    }
}

nonisolated enum SynchronizationTransactionRestorationTarget:
    Hashable,
    Sendable
{
    case targetFile
    case participant(SynchronizationTransactionParticipantKind)
}

nonisolated struct SynchronizationTransactionRestorationFailure:
    Hashable,
    Sendable
{
    let target: SynchronizationTransactionRestorationTarget
    let context: SynchronizationTransactionFailureContext
}

nonisolated enum SynchronizationTransactionError:
    Error,
    Hashable,
    Sendable
{
    case backupCreationFailed(SynchronizationTransactionFailureContext)
    case participantCaptureFailed(
        SynchronizationTransactionParticipantKind,
        SynchronizationTransactionFailureContext
    )
    case executionFailed(SynchronizationTransactionFailure)
    case restorationFailed(SynchronizationTransactionFailure)
    case finalValidationFailed(SynchronizationTransactionFailure)
}
