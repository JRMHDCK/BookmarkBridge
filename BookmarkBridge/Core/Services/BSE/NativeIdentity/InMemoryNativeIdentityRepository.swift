//
//  InMemoryNativeIdentityRepository.swift
//  BookmarkBridge
//

import Foundation
import Synchronization

/// Process-local repository for tests and ephemeral composition. `Mutex`
/// preserves the synchronous contract while making every access race-free.
nonisolated final class InMemoryNativeIdentityRepository: NativeIdentityRepository {
    private struct State: Sendable {
        var nativeByLogical: [LogicalMappingKey: NativeNodeIdentifier] = [:]
        var logicalByNative: [NativeMappingKey: LogicalNodeID] = [:]
    }

    private let storage: Mutex<State>

    init(mappings: [NativeIdentityMapping] = []) {
        var state = State()
        for mapping in mappings {
            Self.register(mapping, in: &state)
        }
        storage = Mutex(state)
    }

    func nativeIdentifier(
        for logicalNodeID: LogicalNodeID,
        sourceID: BSESourceID
    ) -> NativeNodeIdentifier? {
        storage.withLock {
            $0.nativeByLogical[LogicalMappingKey(
                logicalNodeID: logicalNodeID,
                sourceID: sourceID
            )]
        }
    }

    func logicalNodeID(
        for nativeIdentifier: NativeNodeIdentifier,
        sourceID: BSESourceID
    ) -> LogicalNodeID? {
        storage.withLock {
            $0.logicalByNative[NativeMappingKey(
                nativeIdentifier: nativeIdentifier,
                sourceID: sourceID
            )]
        }
    }

    func register(_ mapping: NativeIdentityMapping) {
        storage.withLock {
            Self.register(mapping, in: &$0)
        }
    }

    func remove(
        logicalNodeID: LogicalNodeID,
        sourceID: BSESourceID
    ) {
        storage.withLock {
            let logicalKey = LogicalMappingKey(
                logicalNodeID: logicalNodeID,
                sourceID: sourceID
            )
            guard let nativeIdentifier = $0.nativeByLogical.removeValue(
                forKey: logicalKey
            ) else { return }
            let nativeKey = NativeMappingKey(
                nativeIdentifier: nativeIdentifier,
                sourceID: sourceID
            )
            if $0.logicalByNative[nativeKey] == logicalNodeID {
                $0.logicalByNative.removeValue(forKey: nativeKey)
            }
        }
    }

    func applyAtomically(
        _ mutations: [NativeIdentityRepositoryMutation]
    ) throws -> NativeIdentityRepositoryMutationResult {
        try storage.withLock { state in
            var candidate = state
            var registrationsApplied = 0
            var registrationsAlreadyPresent = 0
            var migrationsApplied = 0

            for mutation in mutations {
                switch mutation {
                case .register(let mapping):
                    if try Self.registerStrict(mapping, in: &candidate) {
                        registrationsApplied += 1
                    } else {
                        registrationsAlreadyPresent += 1
                    }
                case .migrate(let migration):
                    try Self.migrate(migration, in: &candidate)
                    migrationsApplied += 1
                }
            }
            state = candidate
            return NativeIdentityRepositoryMutationResult(
                registrationsApplied: registrationsApplied,
                registrationsAlreadyPresent: registrationsAlreadyPresent,
                migrationsApplied: migrationsApplied
            )
        }
    }

    func transactionSnapshot() throws -> NativeIdentityRepositorySnapshot {
        storage.withLock { state in
            let mappings = state.nativeByLogical.map { entry in
                NativeIdentityMapping(
                    logicalNodeID: entry.key.logicalNodeID,
                    sourceID: entry.key.sourceID,
                    nativeIdentifier: entry.value
                )
            }.sorted(by: Self.mappingPrecedes)
            return NativeIdentityRepositorySnapshot(mappings: mappings)
        }
    }

    func restore(
        transactionSnapshot: NativeIdentityRepositorySnapshot
    ) throws {
        try storage.withLock { state in
            var candidate = State()
            do {
                for mapping in transactionSnapshot.mappings {
                    _ = try Self.registerStrict(mapping, in: &candidate)
                }
            } catch {
                throw NativeIdentityRepositorySnapshotError.invalidSnapshot
            }
            state = candidate
        }
    }

    /// Registration is a deterministic last-write-wins replacement of one
    /// source-local bijection. Both displaced sides are removed first.
    private static func register(
        _ mapping: NativeIdentityMapping,
        in state: inout State
    ) {
        let logicalKey = LogicalMappingKey(
            logicalNodeID: mapping.logicalNodeID,
            sourceID: mapping.sourceID
        )
        let nativeKey = NativeMappingKey(
            nativeIdentifier: mapping.nativeIdentifier,
            sourceID: mapping.sourceID
        )

        if let previousNative = state.nativeByLogical[logicalKey],
           previousNative != mapping.nativeIdentifier {
            let previousNativeKey = NativeMappingKey(
                nativeIdentifier: previousNative,
                sourceID: mapping.sourceID
            )
            if state.logicalByNative[previousNativeKey] == mapping.logicalNodeID {
                state.logicalByNative.removeValue(forKey: previousNativeKey)
            }
        }

        if let previousLogical = state.logicalByNative[nativeKey],
           previousLogical != mapping.logicalNodeID {
            let previousLogicalKey = LogicalMappingKey(
                logicalNodeID: previousLogical,
                sourceID: mapping.sourceID
            )
            if state.nativeByLogical[previousLogicalKey] == mapping.nativeIdentifier {
                state.nativeByLogical.removeValue(forKey: previousLogicalKey)
            }
        }

        state.nativeByLogical[logicalKey] = mapping.nativeIdentifier
        state.logicalByNative[nativeKey] = mapping.logicalNodeID
    }

    private static func registerStrict(
        _ mapping: NativeIdentityMapping,
        in state: inout State
    ) throws -> Bool {
        let logicalKey = LogicalMappingKey(
            logicalNodeID: mapping.logicalNodeID,
            sourceID: mapping.sourceID
        )
        let nativeKey = NativeMappingKey(
            nativeIdentifier: mapping.nativeIdentifier,
            sourceID: mapping.sourceID
        )
        let existingNative = state.nativeByLogical[logicalKey]
        let existingLogical = state.logicalByNative[nativeKey]
        if existingNative == mapping.nativeIdentifier,
           existingLogical == mapping.logicalNodeID {
            return false
        }
        guard existingNative == nil, existingLogical == nil else {
            throw NativeIdentityMigrationError.registrationConflict(mapping)
        }
        state.nativeByLogical[logicalKey] = mapping.nativeIdentifier
        state.logicalByNative[nativeKey] = mapping.logicalNodeID
        return true
    }

    private static func migrate(
        _ migration: NativeIdentityMigration,
        in state: inout State
    ) throws {
        guard migration.fromKind == .chromeIDFallback,
              migration.toKind == .chromeGUID else {
            if migration.fromKind == .opaque
                || migration.toKind == .opaque {
                throw NativeIdentityMigrationError.nonChromeMigration
            }
            throw NativeIdentityMigrationError.invalidTransition(
                from: migration.fromKind,
                to: migration.toKind
            )
        }
        guard migration.continuityProofKind == .chromeIDFallback else {
            throw NativeIdentityMigrationError.missingContinuityProof
        }
        guard migration.continuityProof == migration.from else {
            throw NativeIdentityMigrationError.continuityProofMismatch(
                expected: migration.from,
                observed: migration.continuityProof
            )
        }

        let logicalKey = LogicalMappingKey(
            logicalNodeID: migration.logicalNodeID,
            sourceID: migration.sourceID
        )
        let fromKey = NativeMappingKey(
            nativeIdentifier: migration.from,
            sourceID: migration.sourceID
        )
        let toKey = NativeMappingKey(
            nativeIdentifier: migration.to,
            sourceID: migration.sourceID
        )
        let current = state.nativeByLogical[logicalKey]
        guard current == migration.from else {
            throw NativeIdentityMigrationError.currentIdentityMismatch(
                logicalNodeID: migration.logicalNodeID,
                expected: migration.from,
                actual: current
            )
        }
        if let owner = state.logicalByNative[fromKey],
           owner != migration.logicalNodeID {
            throw NativeIdentityMigrationError
                .sourceIdentityOwnedByAnotherLogicalNode(
                    nativeIdentifier: migration.from,
                    owner: owner
                )
        }
        guard state.logicalByNative[fromKey] == migration.logicalNodeID else {
            throw NativeIdentityMigrationError.currentIdentityMismatch(
                logicalNodeID: migration.logicalNodeID,
                expected: migration.from,
                actual: current
            )
        }
        if let owner = state.logicalByNative[toKey],
           owner != migration.logicalNodeID {
            throw NativeIdentityMigrationError.destinationIdentityAlreadyOwned(
                nativeIdentifier: migration.to,
                owner: owner
            )
        }

        state.logicalByNative.removeValue(forKey: fromKey)
        state.nativeByLogical[logicalKey] = migration.to
        state.logicalByNative[toKey] = migration.logicalNodeID
    }

    private static func mappingPrecedes(
        _ lhs: NativeIdentityMapping,
        _ rhs: NativeIdentityMapping
    ) -> Bool {
        let lhsSource = lhs.sourceID.rawValue.uuidString
        let rhsSource = rhs.sourceID.rawValue.uuidString
        if lhsSource != rhsSource {
            return lhsSource < rhsSource
        }
        let lhsLogical = lhs.logicalNodeID.rawValue.uuidString
        let rhsLogical = rhs.logicalNodeID.rawValue.uuidString
        if lhsLogical != rhsLogical {
            return lhsLogical < rhsLogical
        }
        return lhs.nativeIdentifier.rawValue
            < rhs.nativeIdentifier.rawValue
    }
}

nonisolated private struct LogicalMappingKey: Hashable, Sendable {
    let logicalNodeID: LogicalNodeID
    let sourceID: BSESourceID
}

nonisolated private struct NativeMappingKey: Hashable, Sendable {
    let nativeIdentifier: NativeNodeIdentifier
    let sourceID: BSESourceID
}
