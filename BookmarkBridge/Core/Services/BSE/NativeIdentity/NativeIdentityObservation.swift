//
//  NativeIdentityObservation.swift
//  BookmarkBridge
//

/// Native identity evidence captured during the same coherent read that
/// produced a source-local provisional logical node.
nonisolated struct NativeIdentityObservation: Hashable, Sendable {
    let sourceID: BSESourceID
    let provisionalLogicalNodeID: LogicalNodeID
    let nativeIdentifier: NativeNodeIdentifier
    let nativeIdentityKind: NativeIdentityKind
    let continuityIdentifier: NativeNodeIdentifier?
    let continuityIdentityKind: NativeIdentityKind?

    init(
        sourceID: BSESourceID,
        provisionalLogicalNodeID: LogicalNodeID,
        nativeIdentifier: NativeNodeIdentifier,
        nativeIdentityKind: NativeIdentityKind = .opaque,
        continuityIdentifier: NativeNodeIdentifier? = nil,
        continuityIdentityKind: NativeIdentityKind? = nil
    ) {
        self.sourceID = sourceID
        self.provisionalLogicalNodeID = provisionalLogicalNodeID
        self.nativeIdentifier = nativeIdentifier
        self.nativeIdentityKind = nativeIdentityKind
        self.continuityIdentifier = continuityIdentifier
        self.continuityIdentityKind = continuityIdentityKind
    }
}
