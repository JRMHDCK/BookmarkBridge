//
//  NativeIdentityRepositorySnapshot.swift
//  BookmarkBridge
//

/// Immutable, storage-independent recovery point for the complete native
/// identity bijection. It is captured and restored atomically by a repository.
nonisolated struct NativeIdentityRepositorySnapshot: Hashable, Sendable {
    let mappings: [NativeIdentityMapping]
}

nonisolated enum NativeIdentityRepositorySnapshotError:
    Error,
    Hashable,
    Sendable
{
    case unsupported
    case invalidSnapshot
}
