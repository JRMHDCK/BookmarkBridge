//
//  NativeIdentityKind.swift
//  BookmarkBridge
//

/// Provenance of an opaque native identifier. Only the two Chrome cases may
/// participate in the narrowly defined id-fallback-to-GUID migration.
nonisolated enum NativeIdentityKind: Hashable, Codable, Sendable {
    case opaque
    case chromeIDFallback
    case chromeGUID
}
