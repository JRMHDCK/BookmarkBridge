//
//  MatchingResult.swift
//  BookmarkBridge
//

/// The exhaustive outcome of a BSE matching operation.
///
/// A successful match names the sole matching candidate. An ambiguous result
/// names every valid candidate in deterministic order so the engine never makes
/// an arbitrary choice.
nonisolated enum MatchingResult: Hashable, Codable, Sendable {
    case match(candidateID: LogicalNodeID, reason: MatchingReason)
    case noMatch(reason: MatchingReason)
    case ambiguous(candidateIDs: [LogicalNodeID], reason: MatchingReason)

    var reason: MatchingReason {
        switch self {
        case .match(_, let reason), .noMatch(let reason), .ambiguous(_, let reason):
            reason
        }
    }
}
