//
//  NativeIdentityMigration.swift
//  BookmarkBridge
//

/// Verified replacement of one source-local primary native identity.
nonisolated struct NativeIdentityMigration: Hashable, Sendable {
    let logicalNodeID: LogicalNodeID
    let sourceID: BSESourceID
    let from: NativeNodeIdentifier
    let fromKind: NativeIdentityKind
    let to: NativeNodeIdentifier
    let toKind: NativeIdentityKind
    let continuityProof: NativeNodeIdentifier
    let continuityProofKind: NativeIdentityKind
}

nonisolated enum NativeIdentityRepositoryMutation: Hashable, Sendable {
    case register(NativeIdentityMapping)
    case migrate(NativeIdentityMigration)
}

nonisolated struct NativeIdentityRepositoryMutationResult:
    Hashable,
    Sendable
{
    let registrationsApplied: Int
    let registrationsAlreadyPresent: Int
    let migrationsApplied: Int
}
