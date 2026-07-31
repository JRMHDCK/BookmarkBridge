//
//  MatchingReason.swift
//  BookmarkBridge
//

/// The explicit reason behind a BSE matching decision.
///
/// Reasons describe observed facts only. They carry no diff, conflict, or
/// planning semantics and can be extended without changing the three possible
/// `MatchingResult` outcomes.
nonisolated enum MatchingReason: Hashable, Codable, Sendable {
    case sameLogicalID
    case samePermanentRootRole
    case sameBookmarkURL
    case sameBookmarkURLAndStructure
    case sameFolderPath
    case differentLogicalID
    case differentPermanentRootRole
    case differentBookmarkURL
    case differentNodeKind
    case noCandidates
    case noMatchingCandidate
    case ambiguousCandidates(count: Int)
    case missingInformation
}
