//
//  PermanentRootRole.swift
//  BookmarkBridge
//

/// Source-neutral role explicitly declared by a Reader for a permanent root.
///
/// Equality means that two roots are homologous across sources. The role is
/// never inferred from user-visible content or hierarchy.
nonisolated enum PermanentRootRole: String, Hashable, Codable, Sendable {
    case primaryBookmarks
    case secondaryBookmarks
    case mobileBookmarks
    case readingList
}
