//
//  NativeIdentityBootstrapError.swift
//  BookmarkBridge
//

nonisolated enum NativeIdentityBootstrapError: Error, Hashable, Sendable {
    case observationWithoutDurableIdentity(NativeIdentityObservation)
    case inconsistentReconciliation(
        reference: IdentityNodeReference,
        first: LogicalNodeID,
        second: LogicalNodeID
    )
    case duplicateObservation(
        reference: IdentityNodeReference,
        first: NativeNodeIdentifier,
        second: NativeNodeIdentifier
    )
    case durableLogicalNodeConflict(
        sourceID: BSESourceID,
        logicalNodeID: LogicalNodeID,
        existing: NativeNodeIdentifier,
        observed: NativeNodeIdentifier
    )
    case nativeIdentifierConflict(
        sourceID: BSESourceID,
        nativeIdentifier: NativeNodeIdentifier,
        existing: LogicalNodeID,
        observed: LogicalNodeID
    )
    case inconsistentRepository(
        sourceID: BSESourceID,
        logicalNodeID: LogicalNodeID,
        nativeIdentifier: NativeNodeIdentifier
    )
}
