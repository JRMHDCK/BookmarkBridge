//
//  IdentityReconciliationRequest.swift
//  BookmarkBridge
//

/// Complete immutable business input. Services are constructor-injected into
/// the engine and never travel in a request.
nonisolated struct IdentityReconciliationRequest: Hashable, Sendable {
    let baseline: Baseline
    let snapshots: [BSESnapshot]
    let matchingGroups: [IdentityMatchingGroup]
}
