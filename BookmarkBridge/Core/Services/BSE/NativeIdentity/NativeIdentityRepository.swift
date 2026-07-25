//
//  NativeIdentityRepository.swift
//  BookmarkBridge
//

/// Generic source-identity registry used by identity bootstrap and write-side
/// composition. Implementations must synchronize mutable storage internally.
nonisolated protocol NativeIdentityRepository: Sendable {
    func nativeIdentifier(
        for logicalNodeID: LogicalNodeID,
        sourceID: BSESourceID
    ) -> NativeNodeIdentifier?

    func logicalNodeID(
        for nativeIdentifier: NativeNodeIdentifier,
        sourceID: BSESourceID
    ) -> LogicalNodeID?

    /// Registers a source-local one-to-one mapping. Re-registering the same
    /// mapping is a no-op. A different mapping replaces any previous mapping
    /// that owns either endpoint, without leaving a stale reverse entry.
    func register(_ mapping: NativeIdentityMapping)

    func remove(
        logicalNodeID: LogicalNodeID,
        sourceID: BSESourceID
    )

    /// Validates the complete batch against one repository state, then commits
    /// every mutation together. No mutation is visible when validation fails.
    func applyAtomically(
        _ mutations: [NativeIdentityRepositoryMutation]
    ) throws -> NativeIdentityRepositoryMutationResult

    /// Captures the complete source-local bijection in one atomic read.
    func transactionSnapshot() throws -> NativeIdentityRepositorySnapshot

    /// Atomically replaces the complete bijection with a prior snapshot.
    func restore(
        transactionSnapshot: NativeIdentityRepositorySnapshot
    ) throws
}

extension NativeIdentityRepository {
    func applyAtomically(
        _ mutations: [NativeIdentityRepositoryMutation]
    ) throws -> NativeIdentityRepositoryMutationResult {
        guard mutations.isEmpty else {
            throw NativeIdentityMigrationError.unsupportedAtomicMutation
        }
        return NativeIdentityRepositoryMutationResult(
            registrationsApplied: 0,
            registrationsAlreadyPresent: 0,
            migrationsApplied: 0
        )
    }

    func transactionSnapshot() throws -> NativeIdentityRepositorySnapshot {
        throw NativeIdentityRepositorySnapshotError.unsupported
    }

    func restore(
        transactionSnapshot: NativeIdentityRepositorySnapshot
    ) throws {
        throw NativeIdentityRepositorySnapshotError.unsupported
    }
}
