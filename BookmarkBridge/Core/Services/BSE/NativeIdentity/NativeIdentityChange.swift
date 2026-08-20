//
//  NativeIdentityChange.swift
//  BookmarkBridge
//

/// A repository update committed only after its browser document is saved.
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
