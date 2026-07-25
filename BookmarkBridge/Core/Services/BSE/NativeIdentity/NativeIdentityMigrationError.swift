//
//  NativeIdentityMigrationError.swift
//  BookmarkBridge
//

nonisolated enum NativeIdentityMigrationError: Error, Hashable, Sendable {
    case unsupportedAtomicMutation
    case nonChromeMigration
    case invalidTransition(
        from: NativeIdentityKind,
        to: NativeIdentityKind
    )
    case missingContinuityProof
    case continuityProofMismatch(
        expected: NativeNodeIdentifier,
        observed: NativeNodeIdentifier
    )
    case currentIdentityMismatch(
        logicalNodeID: LogicalNodeID,
        expected: NativeNodeIdentifier,
        actual: NativeNodeIdentifier?
    )
    case sourceIdentityOwnedByAnotherLogicalNode(
        nativeIdentifier: NativeNodeIdentifier,
        owner: LogicalNodeID
    )
    case destinationIdentityAlreadyOwned(
        nativeIdentifier: NativeNodeIdentifier,
        owner: LogicalNodeID
    )
    case registrationConflict(NativeIdentityMapping)
}
