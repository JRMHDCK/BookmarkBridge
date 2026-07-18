//
//  IdentityMatchingPolicy.swift
//  BookmarkBridge
//

import Foundation

/// A source-local occurrence participating in one externally matched group.
nonisolated struct IdentityNodeReference: Hashable, Codable, Sendable, Comparable {
    let sourceID: BSESourceID
    let provisionalLogicalID: LogicalNodeID

    static func < (lhs: IdentityNodeReference, rhs: IdentityNodeReference) -> Bool {
        let lhsSource = lhs.sourceID.rawValue.uuidString
        let rhsSource = rhs.sourceID.rawValue.uuidString
        if lhsSource != rhsSource { return lhsSource < rhsSource }
        return lhs.provisionalLogicalID < rhs.provisionalLogicalID
    }
}

/// One group already evaluated by Matching Engine. Reconciliation never
/// recalculates similarity and only consumes this supplied result.
nonisolated struct IdentityMatchingGroup: Hashable, Codable, Sendable {
    let members: [IdentityNodeReference]
    let matchingResult: MatchingResult

    init(members: [IdentityNodeReference], matchingResult: MatchingResult) {
        self.members = members.sorted()
        self.matchingResult = matchingResult
    }
}

nonisolated struct IdentityMatchingContext: Hashable, Sendable {
    let baseline: Baseline
    let group: IdentityMatchingGroup
}

/// Exhaustive identity decision applied by the engine.
nonisolated enum IdentityMatchingDecision: Hashable, Codable, Sendable {
    case reuse(LogicalNodeID)
    case create
    case ambiguous(candidateIDs: [LogicalNodeID])
}

/// Policy boundary for identity decisions. Implementations may evolve without
/// adding heuristics or thresholds to the reconciliation engine.
nonisolated protocol IdentityMatchingPolicy: Sendable {
    func decide(for context: IdentityMatchingContext) throws -> IdentityMatchingDecision
}

/// Conservative policy based only on existing Baseline observations and the
/// already-computed MatchingResult. It never compares node content.
nonisolated struct StrictIdentityMatchingPolicy: IdentityMatchingPolicy {
    func decide(for context: IdentityMatchingContext) throws -> IdentityMatchingDecision {
        let baselineCandidates = context.baseline.identityRecords.compactMap { record in
            record.observations.contains { observation in
                context.group.members.contains(IdentityNodeReference(
                    sourceID: observation.sourceID,
                    provisionalLogicalID: observation.provisionalLogicalID
                ))
            } ? record.logicalNodeID : nil
        }.sorted()

        if baselineCandidates.count == 1 {
            return .reuse(baselineCandidates[0])
        }
        if baselineCandidates.count > 1 {
            return .ambiguous(candidateIDs: baselineCandidates)
        }

        switch context.group.matchingResult {
        case .ambiguous(let candidateIDs, _):
            return .ambiguous(candidateIDs: candidateIDs.sorted())
        case .match(let candidateID, _):
            guard context.group.members.contains(where: {
                $0.provisionalLogicalID == candidateID
            }) else {
                return .ambiguous(candidateIDs: [candidateID])
            }
            return .create
        case .noMatch:
            return .create
        }
    }
}
