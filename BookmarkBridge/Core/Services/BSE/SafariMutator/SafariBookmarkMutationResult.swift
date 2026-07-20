//
//  SafariBookmarkMutationResult.swift
//  BookmarkBridge
//

/// A native-identity repository update to perform only after the mutated
/// document has been persisted successfully.
nonisolated enum NativeIdentityChange: Hashable, Sendable {
    case register(
        logicalNodeID: LogicalNodeID,
        sourceID: BSESourceID,
        nativeIdentifier: NativeNodeIdentifier
    )
    case remove(
        logicalNodeID: LogicalNodeID,
        sourceID: BSESourceID
    )
}

/// The complete in-memory mutation outcome. Identity changes are deliberately
/// deferred so the persistence boundary can commit them after a successful save.
nonisolated struct SafariBookmarkMutationResult: Hashable, Sendable {
    let document: SafariBookmarkDocument
    let nativeIdentityChanges: [NativeIdentityChange]
}
