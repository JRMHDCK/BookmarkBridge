//
//  NativeIdentityRepository.swift
//  BookmarkBridge
//

/// Generic source-identity registry used by write-side composition only.
/// Implementations must synchronize mutable storage internally.
nonisolated protocol NativeIdentityRepository: Sendable {
    func nativeIdentifier(
        for logicalNodeID: LogicalNodeID,
        sourceID: BSESourceID
    ) -> NativeNodeIdentifier?

    func register(_ mapping: NativeIdentityMapping)

    func remove(
        logicalNodeID: LogicalNodeID,
        sourceID: BSESourceID
    )
}
