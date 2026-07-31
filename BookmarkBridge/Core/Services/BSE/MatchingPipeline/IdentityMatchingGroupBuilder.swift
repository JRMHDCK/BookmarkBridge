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
                    let matchingCandidates = candidates.filter {
                        candidateIDs.contains($0.provisionalLogicalID)
                    }
                    if let candidate = uniqueStructuralCandidate(
                        for: seed,
                        among: matchingCandidates,
                        occurrences: occurrences
                    ) {
                        members.append(candidate)
                        successfulMatches.append((
                            candidate,
                            .sameBookmarkURLAndStructure
                        ))
                        remaining.remove(candidate)
                    } else {
                        ambiguousCandidateIDs.formUnion(candidateIDs)
                        for candidate in matchingCandidates {
                            remaining.remove(candidate)
                        }
                    }

                case .noMatch:
                    guard let candidate = uniqueFolderPathCandidate(
                        for: seed,
                        among: candidates,
                        occurrences: occurrences
                    ) else {
                        continue
                    }
                    members.append(candidate)
                    successfulMatches.append((candidate, .sameFolderPath))
                    remaining.remove(candidate)
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
                matchingResult: matchingResult,
                permanentRootRole: seedNode.permanentRootRole
            ))
        }

        return groups.sorted(by: groupOrder)
    }

    /// Resolves a URL-only ambiguity only when one candidate has the exact
    /// bookmark title and immediate parent-folder identity. Position and higher
    /// ancestors are intentionally excluded because a legitimate reorder or
    /// parent-folder move must remain matchable.
    ///
    /// No best-effort score or ordering fallback is used: zero or multiple
    /// structural matches preserve the original ambiguity.
    private func uniqueStructuralCandidate(
        for seed: IdentityNodeReference,
        among candidates: [IdentityNodeReference],
        occurrences: [IdentityNodeReference: BSENode]
    ) -> IdentityNodeReference? {
        guard let seedNode = occurrences[seed],
              seedNode.kind == .bookmark,
              let seedSignature = localStructure(
                for: seed,
                node: seedNode,
                occurrences: occurrences
              ) else {
            return nil
        }
        let exact = candidates.filter { candidate in
            guard let node = occurrences[candidate],
                  node.kind == .bookmark else {
                return false
            }
            return localStructure(
                for: candidate,
                node: node,
                occurrences: occurrences
            ) == seedSignature
        }
        return exact.count == 1 ? exact[0] : nil
    }

    /// Folder identifiers are browser-local. An exact path below a homologous
    /// permanent root is the only cross-browser structural evidence accepted
    /// for ordinary folders. Ambiguous duplicate paths remain unmatched.
    private func uniqueFolderPathCandidate(
        for seed: IdentityNodeReference,
        among candidates: [IdentityNodeReference],
        occurrences: [IdentityNodeReference: BSENode]
    ) -> IdentityNodeReference? {
        guard let seedNode = occurrences[seed],
              let seedPath = folderPath(
                for: seed,
                node: seedNode,
                occurrences: occurrences
              ) else {
            return nil
        }
        let exact = candidates.filter { candidate in
            guard let node = occurrences[candidate] else {
                return false
            }
            return folderPath(
                for: candidate,
                node: node,
                occurrences: occurrences
            ) == seedPath
        }
        return exact.count == 1 ? exact[0] : nil
    }

    private func folderPath(
        for reference: IdentityNodeReference,
        node: BSENode,
        occurrences: [IdentityNodeReference: BSENode]
    ) -> FolderStructuralPath? {
        guard node.kind == .folder,
              node.permanentRootRole == nil else {
            return nil
        }
        var titles = [node.title]
        var parentID = node.parentID
        var visited: Set<LogicalNodeID> = [node.logicalID]

        while let currentParentID = parentID {
            guard visited.insert(currentParentID).inserted,
                  let parent = occurrences[IdentityNodeReference(
                    sourceID: reference.sourceID,
                    provisionalLogicalID: currentParentID
                  )],
                  parent.kind == .folder else {
                return nil
            }
            if let rootRole = parent.permanentRootRole {
                return FolderStructuralPath(
                    rootRole: rootRole,
                    titles: Array(titles.reversed())
                )
            }
            titles.append(parent.title)
            parentID = parent.parentID
        }
        return nil
    }

    private func localStructure(
        for reference: IdentityNodeReference,
        node: BSENode,
        occurrences: [IdentityNodeReference: BSENode]
    ) -> BookmarkLocalStructure? {
        guard let parentID = node.parentID,
              let parent = occurrences[IdentityNodeReference(
                sourceID: reference.sourceID,
                provisionalLogicalID: parentID
              )],
              parent.kind == .folder else {
            return nil
        }
        return BookmarkLocalStructure(
            title: node.title,
            parentTitle: parent.title
        )
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

nonisolated private struct BookmarkLocalStructure: Hashable, Sendable {
    let title: String
    let parentTitle: String
}

nonisolated private struct FolderStructuralPath: Hashable, Sendable {
    let rootRole: PermanentRootRole
    let titles: [String]
}
