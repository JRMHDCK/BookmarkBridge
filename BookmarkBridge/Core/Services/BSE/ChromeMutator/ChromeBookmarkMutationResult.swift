//
//  ChromeBookmarkMutationResult.swift
//  BookmarkBridge
//

/// Complete in-memory outcome. Identity changes remain deferred until a future
/// write adapter has persisted the returned document successfully.
nonisolated struct ChromeBookmarkMutationResult: Hashable, Sendable {
    let document: ChromeBookmarkDocument
    let nativeIdentityChanges: [NativeIdentityChange]
}
