//
//  SynchronizationTransactionParticipant.swift
//  BookmarkBridge
//

nonisolated enum SynchronizationTransactionParticipantKind:
    String,
    Hashable,
    Codable,
    Sendable
{
    case baseline
    case nativeIdentityRepository
}

/// A captured participant owns an immutable recovery point. Committing only
/// releases that point; all durable mutations remain owned by the component.
nonisolated struct SynchronizationTransactionCheckpoint: Sendable {
    let kind: SynchronizationTransactionParticipantKind
    private let rollbackAction: @Sendable () async throws -> Void

    init(
        kind: SynchronizationTransactionParticipantKind,
        rollbackAction: @escaping @Sendable () async throws -> Void
    ) {
        self.kind = kind
        self.rollbackAction = rollbackAction
    }

    func rollback() async throws {
        try await rollbackAction()
    }
}

/// Generic boundary for durable BSE state participating in the same recovery
/// scope as the browser file.
nonisolated protocol SynchronizationTransactionParticipant: Sendable {
    var kind: SynchronizationTransactionParticipantKind { get }

    func capture() async throws -> SynchronizationTransactionCheckpoint
}

nonisolated struct BaselineSynchronizationTransactionParticipant:
    SynchronizationTransactionParticipant
{
    let repository: BaselineRepository

    var kind: SynchronizationTransactionParticipantKind {
        .baseline
    }

    func capture() async throws -> SynchronizationTransactionCheckpoint {
        let snapshot = try await repository.transactionSnapshot()
        return SynchronizationTransactionCheckpoint(kind: kind) {
            try await repository.restoreTransactionSnapshot(snapshot)
        }
    }
}

nonisolated struct NativeIdentitySynchronizationTransactionParticipant:
    SynchronizationTransactionParticipant
{
    let repository: any NativeIdentityRepository

    var kind: SynchronizationTransactionParticipantKind {
        .nativeIdentityRepository
    }

    func capture() async throws -> SynchronizationTransactionCheckpoint {
        let snapshot = try repository.transactionSnapshot()
        return SynchronizationTransactionCheckpoint(kind: kind) {
            try repository.restore(transactionSnapshot: snapshot)
        }
    }
}
