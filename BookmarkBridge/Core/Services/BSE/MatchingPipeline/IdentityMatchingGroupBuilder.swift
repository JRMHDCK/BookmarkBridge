//
//  IdentityMatchingGroupBuilder.swift
//  BookmarkBridge
//

nonisolated protocol MatchingPipelineMatching: Sendable {
    func match(_ node: BSENode, among candidates: [BSENode]) throws -> MatchingResult
}

extension MatchingEngine: MatchingPipelineMatching {}

nonisolated protocol IdentityMatchingGroupBuilding: Sendable {
    func build(
        baseline: Baseline,
        snapshots: [BSESnapshot],
        matchingEngine: any MatchingPipelineMatching
    ) throws -> [IdentityMatchingGroup]
}

/// Partitions source-local occurrences without comparing their content. Known
/// Baseline observations are grouped by their durable identity; every remaining
/// comparison is delegated verbatim to Matching Engine.
nonisolated struct DefaultIdentityMatchingGroupBuilder: IdentityMatchingGroupBuilding {
    func build(
        baseline: Baseline,
        snapshots: [BSESnapshot],
        matchingEngine: any MatchingPipelineMatching
    ) throws -> [IdentityMatchingGroup] {
        let occurrences = occurrenceIndex(snapshots)
        let durableIdentitiesByReference = durableIdentityIndex(baseline)
        var remaining = Set(occurrences.keys)
        var groups: [IdentityMatchingGroup] = []

        while let seed = nextSeed(
            in: remaining,
            durableIdentitiesByReference: durableIdentitiesByReference
        ) {
            guard let seedNode = occurrences[seed] else { break }
            remaining.remove(seed)

            var members = [seed]
            if let durableIdentities = durableIdentitiesByReference[seed],
               durableIdentities.count == 1,
               let durableIdentity = durableIdentities.first {
                let knownMembers = remaining.filter {
                    durableIdentitiesByReference[$0] == [durableIdentity]
                }.sorted()
                members.append(contentsOf: knownMembers)
                remaining.subtract(knownMembers)
            }
            var successfulMatches: [(IdentityNodeReference, MatchingReason)] = []
            var ambiguousCandidateIDs: Set<LogicalNodeID> = []

            for snapshot in snapshots where !members.contains(where: {
                $0.sourceID == snapshot.source
            }) {
                let candidates = remaining
                    .filter { $0.sourceID == snapshot.source }
                    .sorted()
                let candidateNodes = candidates.compactMap { occurrences[$0] }
                let result = try matchingEngine.match(seedNode, among: candidateNodes)

                switch result {
                case .match(let candidateID, let reason):
                    guard let candidate = candidates.first(where: {
                        $0.provisionalLogicalID == candidateID
                    }) else { continue }
                    members.append(candidate)
                    successfulMatches.append((candidate, reason))
                    remaining.remove(candidate)

                case .ambiguous(let candidateIDs, _):
                    ambiguousCandidateIDs.formUnion(candidateIDs)
                    for candidate in candidates where candidateIDs.contains(
                        candidate.provisionalLogicalID
                    ) {
                        remaining.remove(candidate)
                    }

                case .noMatch:
                    continue
                }
            }

            let matchingResult: MatchingResult
            if !ambiguousCandidateIDs.isEmpty {
                let candidateIDs = ambiguousCandidateIDs.sorted()
                matchingResult = .ambiguous(
                    candidateIDs: candidateIDs,
                    reason: .ambiguousCandidates(count: candidateIDs.count)
                )
            } else if let firstMatch = successfulMatches.sorted(by: {
                $0.0 < $1.0
            }).first {
                matchingResult = .match(
                    candidateID: firstMatch.0.provisionalLogicalID,
                    reason: firstMatch.1
                )
            } else {
                matchingResult = .noMatch(reason: .noMatchingCandidate)
            }

            groups.append(IdentityMatchingGroup(
                members: members,
                matchingResult: matchingResult
            ))
        }

        return groups.sorted(by: groupOrder)
    }

    private func nextSeed(
        in remaining: Set<IdentityNodeReference>,
        durableIdentitiesByReference: [IdentityNodeReference: Set<LogicalNodeID>]
    ) -> IdentityNodeReference? {
        remaining.sorted { lhs, rhs in
            let lhsIsKnown = durableIdentitiesByReference[lhs]?.isEmpty == false
            let rhsIsKnown = durableIdentitiesByReference[rhs]?.isEmpty == false
            if lhsIsKnown != rhsIsKnown { return lhsIsKnown }
            return lhs < rhs
        }.first
    }

    private func occurrenceIndex(
        _ snapshots: [BSESnapshot]
    ) -> [IdentityNodeReference: BSENode] {
        Dictionary(uniqueKeysWithValues: snapshots.flatMap { snapshot in
            snapshot.tree.nodes.map { node in
                (
                    IdentityNodeReference(
                        sourceID: snapshot.source,
                        provisionalLogicalID: node.logicalID
                    ),
                    node
                )
            }
        })
    }

    private func durableIdentityIndex(
        _ baseline: Baseline
    ) -> [IdentityNodeReference: Set<LogicalNodeID>] {
        var identities: [IdentityNodeReference: Set<LogicalNodeID>] = [:]
        for record in baseline.identityRecords {
            for observation in record.observations {
                let reference = IdentityNodeReference(
                    sourceID: observation.sourceID,
                    provisionalLogicalID: observation.provisionalLogicalID
                )
                identities[reference, default: []].insert(record.logicalNodeID)
            }
        }
        return identities
    }

    private func groupOrder(
        _ lhs: IdentityMatchingGroup,
        _ rhs: IdentityMatchingGroup
    ) -> Bool {
        guard let lhsFirst = lhs.members.first, let rhsFirst = rhs.members.first else {
            return lhs.members.count < rhs.members.count
        }
        return lhsFirst < rhsFirst
    }
}
