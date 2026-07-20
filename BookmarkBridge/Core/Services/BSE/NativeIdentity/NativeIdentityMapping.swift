//
//  NativeIdentityMapping.swift
//  BookmarkBridge
//

/// One source-specific correspondence for a durable BSE identity.
nonisolated struct NativeIdentityMapping: Hashable, Codable, Sendable {
    let logicalNodeID: LogicalNodeID
    let sourceID: BSESourceID
    let nativeIdentifier: NativeNodeIdentifier

    init(
        logicalNodeID: LogicalNodeID,
        sourceID: BSESourceID,
        nativeIdentifier: NativeNodeIdentifier
    ) {
        self.logicalNodeID = logicalNodeID
        self.sourceID = sourceID
        self.nativeIdentifier = nativeIdentifier
    }
}
