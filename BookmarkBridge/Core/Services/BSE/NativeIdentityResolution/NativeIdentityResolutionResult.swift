//
//  NativeIdentityResolutionResult.swift
//  BookmarkBridge
//

/// One read result whose known native identities have been replaced by their
/// durable logical identities for the current pipeline pass.
nonisolated struct NativeIdentityResolutionResult: Hashable, Sendable {
    let readResult: EndToEndSynchronizationReadResult
    let resolvedIdentityCount: Int
    let unresolvedIdentityCount: Int
}
