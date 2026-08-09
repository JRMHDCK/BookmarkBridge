import Foundation

/// Synchronization preparation for observationally identical duplicate
/// bookmarks.
///
/// Strict BSE matching intentionally reports several equal candidates as
/// ambiguous. That decision remains unchanged. Equal occurrences have no
/// observable distinction, so pairing them by established logical identity and
/// then stable occurrence order preserves their multiplicity without inventing
/// a semantic preference. The regular BSE builder still handles every other
/// node.
nonisolated struct SynchronizationDuplicateIdentityMatchingGroupBuilder:
    IdentityMatchingGroupBuilding
{
    private let base = DefaultIdentityMatchingGroupBuilder()

    func build(
        baseline: Baseline,
        snapshots: [BSESnapshot],
        matchingEngine: any MatchingPipelineMatching
    ) throws -> [IdentityMatchingGroup] {
        let prepared = prepareEquivalentDuplicates(
            snapshots: snapshots
        )
        guard !prepared.groups.isEmpty else {
            return try base.build(
                baseline: baseline,
                snapshots: snapshots,
                matchingEngine: matchingEngine
            )
        }

        let remaining = try snapshots.map {
            try removing(prepared.references, from: $0)
        }
        let regular = try base.build(
            baseline: baseline,
            snapshots: remaining,
            matchingEngine: matchingEngine
        )
        return (prepared.groups + regular).sorted(by: groupPrecedes)
    }

    private func prepareEquivalentDuplicates(
        snapshots: [BSESnapshot]
    ) -> PreparedDuplicateGroups {
        let nodes = nodeIndex(snapshots)
        var occurrences: [DuplicateSignature: [BSESourceID: [IdentityNodeReference]]] = [:]

        for snapshot in snapshots {
            for node in snapshot.tree.nodes where node.kind == .bookmark {
                let reference = IdentityNodeReference(
                    sourceID: snapshot.source,
                    provisionalLogicalID: node.logicalID
                )
                guard let signature = signature(
                    reference,
                    node: node,
                    nodes: nodes
                ) else {
                    continue
                }
                occurrences[signature, default: [:]][
                    snapshot.source,
                    default: []
                ].append(reference)
            }
        }

        var groups: [IdentityMatchingGroup] = []
        var handled: Set<IdentityNodeReference> = []
        for bySource in occurrences.values {
            let orderedSources = bySource.keys.sorted {
                $0.rawValue.uuidString < $1.rawValue.uuidString
            }
            guard orderedSources.count > 1,
                  bySource.values.contains(where: { $0.count > 1 }) else {
                continue
            }
            var ordered = orderedSources.map { source in
                (bySource[source] ?? []).sorted {
                    nodePrecedes($0, $1, nodes: nodes)
                }
            }
            let referencesByLogicalID = Dictionary(
                grouping: ordered.flatMap { $0 },
                by: \.provisionalLogicalID
            )
            for logicalID in referencesByLogicalID.keys.sorted() {
                guard let members = referencesByLogicalID[logicalID],
                      Set(members.map(\.sourceID)).count > 1 else {
                    continue
                }
                handled.formUnion(members)
                groups.append(matchedGroup(members, nodes: nodes))
                for index in ordered.indices {
                    ordered[index].removeAll {
                        $0.provisionalLogicalID == logicalID
                    }
                }
            }
            let maximumCount = ordered.map(\.count).max() ?? 0
            for index in 0..<maximumCount {
                let members = ordered.compactMap {
                    index < $0.count ? $0[index] : nil
                }
                guard !members.isEmpty else { continue }
                handled.formUnion(members)
                if members.count > 1 {
                    groups.append(matchedGroup(members, nodes: nodes))
                } else {
                    groups.append(IdentityMatchingGroup(
                        members: members,
                        matchingResult: .noMatch(
                            reason: .noMatchingCandidate
                        ),
                        permanentRootRole: nil
                    ))
                }
            }
        }
        return PreparedDuplicateGroups(groups: groups, references: handled)
    }

    private func matchedGroup(
        _ members: [IdentityNodeReference],
        nodes: [IdentityNodeReference: BSENode]
    ) -> IdentityMatchingGroup {
        guard let first = members.first,
              let candidate = members.dropFirst().first else {
            return IdentityMatchingGroup(
                members: members,
                matchingResult: .noMatch(reason: .noMatchingCandidate),
                permanentRootRole: nil
            )
        }
        return IdentityMatchingGroup(
            members: members,
            matchingResult: .match(
                candidateID: candidate.provisionalLogicalID,
                reason: .sameBookmarkURLAndStructure
            ),
            permanentRootRole: nodes[first]?.permanentRootRole
        )
    }

    private func signature(
        _ reference: IdentityNodeReference,
        node: BSENode,
        nodes: [IdentityNodeReference: BSENode]
    ) -> DuplicateSignature? {
        guard let url = node.url else { return nil }
        var parentTitles: [String] = []
        var parentID = node.parentID
        var rootRole: PermanentRootRole?
        var visited: Set<LogicalNodeID> = []
        while let current = parentID {
            guard visited.insert(current).inserted,
                  let parent = nodes[IdentityNodeReference(
                    sourceID: reference.sourceID,
                    provisionalLogicalID: current
                  )],
                  parent.kind == .folder else {
                return nil
            }
            if let role = parent.permanentRootRole {
                rootRole = role
                break
            }
            parentTitles.append(parent.title)
            parentID = parent.parentID
        }
        guard let rootRole else { return nil }
        return DuplicateSignature(
            url: url.absoluteString,
            title: node.title,
            rootRole: rootRole,
            parentTitles: parentTitles.reversed()
        )
    }

    private func nodeIndex(
        _ snapshots: [BSESnapshot]
    ) -> [IdentityNodeReference: BSENode] {
        Dictionary(uniqueKeysWithValues: snapshots.flatMap { snapshot in
            snapshot.tree.nodes.map {
                (
                    IdentityNodeReference(
                        sourceID: snapshot.source,
                        provisionalLogicalID: $0.logicalID
                    ),
                    $0
                )
            }
        })
    }

    private func removing(
        _ references: Set<IdentityNodeReference>,
        from snapshot: BSESnapshot
    ) throws -> BSESnapshot {
        let retained = snapshot.tree.nodes.filter {
            !references.contains(IdentityNodeReference(
                sourceID: snapshot.source,
                provisionalLogicalID: $0.logicalID
            ))
        }
        let positions = Dictionary(grouping: retained, by: \.parentID)
            .mapValues { siblings in
                Dictionary(uniqueKeysWithValues: siblings.sorted {
                    if $0.position != $1.position {
                        return $0.position < $1.position
                    }
                    return $0.logicalID < $1.logicalID
                }.enumerated().map { ($0.element.logicalID, $0.offset) })
            }
        let normalized = try retained.map { node in
            try BSENode(
                logicalID: node.logicalID,
                kind: node.kind,
                permanentRootRole: node.permanentRootRole,
                title: node.title,
                parentID: node.parentID,
                position: positions[node.parentID]?[node.logicalID]
                    ?? node.position,
                url: node.url
            )
        }
        return BSESnapshot(
            source: snapshot.source,
            capturedAt: snapshot.capturedAt,
            tree: try BSETree(nodes: normalized)
        )
    }

    private func nodePrecedes(
        _ lhs: IdentityNodeReference,
        _ rhs: IdentityNodeReference,
        nodes: [IdentityNodeReference: BSENode]
    ) -> Bool {
        let lhsPosition = nodes[lhs]?.position ?? 0
        let rhsPosition = nodes[rhs]?.position ?? 0
        if lhsPosition != rhsPosition { return lhsPosition < rhsPosition }
        return lhs < rhs
    }

    private func groupPrecedes(
        _ lhs: IdentityMatchingGroup,
        _ rhs: IdentityMatchingGroup
    ) -> Bool {
        guard let lhsFirst = lhs.members.first,
              let rhsFirst = rhs.members.first else {
            return lhs.members.count < rhs.members.count
        }
        return lhsFirst < rhsFirst
    }
}

nonisolated private struct PreparedDuplicateGroups: Sendable {
    let groups: [IdentityMatchingGroup]
    let references: Set<IdentityNodeReference>
}

nonisolated private struct DuplicateSignature: Hashable, Sendable {
    let url: String
    let title: String
    let rootRole: PermanentRootRole
    let parentTitles: [String]
}
