//
//  MatchingEngine.swift
//  BookmarkBridge
//

import Foundation

/// Pure, deterministic matching of universal BSE nodes.
///
/// The engine observes nodes only. It never mutates a tree, emits events,
/// computes a diff, resolves a conflict, or creates a plan.
nonisolated struct MatchingEngine: Sendable {

    init() {}

    /// Determines whether `node` and one `candidate` represent the same logical
    /// object according to the validated BSE-110 rules.
    func match(_ node: BSENode, with candidate: BSENode) -> MatchingResult {
        guard node.kind == candidate.kind else {
            return .noMatch(reason: .differentNodeKind)
        }

        if let nodeRole = node.permanentRootRole,
           let candidateRole = candidate.permanentRootRole {
            guard nodeRole == candidateRole else {
                return .noMatch(reason: .differentPermanentRootRole)
            }
            return .match(
                candidateID: candidate.logicalID,
                reason: .samePermanentRootRole
            )
        }
        if node.permanentRootRole != nil || candidate.permanentRootRole != nil {
            return .noMatch(reason: .differentPermanentRootRole)
        }

        if node.logicalID == candidate.logicalID {
            return .match(candidateID: candidate.logicalID, reason: .sameLogicalID)
        }

        switch node.kind {
        case .folder:
            return .noMatch(reason: .differentLogicalID)
        case .bookmark:
            guard let nodeURL = node.url, let candidateURL = candidate.url else {
                return .noMatch(reason: .missingInformation)
            }
            if nodeURL.absoluteString == candidateURL.absoluteString {
                return .match(candidateID: candidate.logicalID, reason: .sameBookmarkURL)
            }
            return .noMatch(reason: .differentBookmarkURL)
        }
    }

    /// Finds the logical counterpart of `node` among `candidates`.
    ///
    /// Every valid candidate is retained. More than one produces `.ambiguous`;
    /// identifiers are sorted to make the result independent of input order.
    func match(_ node: BSENode, among candidates: [BSENode]) -> MatchingResult {
        guard !candidates.isEmpty else {
            return .noMatch(reason: .noCandidates)
        }

        let matches = candidates.compactMap { candidate -> (LogicalNodeID, MatchingReason)? in
            guard case .match(let candidateID, let reason) = match(node, with: candidate) else {
                return nil
            }
            return (candidateID, reason)
        }

        switch matches.count {
        case 0:
            if candidates.count == 1 {
                return match(node, with: candidates[0])
            }
            return .noMatch(reason: .noMatchingCandidate)
        case 1:
            return .match(candidateID: matches[0].0, reason: matches[0].1)
        default:
            let candidateIDs = matches.map(\.0).sorted()
            return .ambiguous(
                candidateIDs: candidateIDs,
                reason: .ambiguousCandidates(count: candidateIDs.count)
            )
        }
    }
}
