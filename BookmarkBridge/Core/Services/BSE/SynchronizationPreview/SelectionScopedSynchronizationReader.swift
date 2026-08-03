import Foundation

/// Read-boundary decorator. Nodes outside the user selection never enter BSE.
nonisolated struct SelectionScopedSynchronizationReader:
    EndToEndSynchronizationReading
{
    let reader: any EndToEndSynchronizationReading
    let selection: SynchronizationSelectionScope

    var sourceID: BSESourceID { reader.sourceID }

    func readForSynchronization() async throws
        -> EndToEndSynchronizationReadResult {
        let result = try await reader.readForSynchronization()
        guard case .nativeIdentifiers(
            let identifiers,
            includingSemanticKeys: let includedSemanticKeys,
            excludingSemanticKeys: let excludedSemanticKeys
        ) = selection else {
            return result
        }

        let observationByNode = Dictionary(
            uniqueKeysWithValues: result.nativeIdentityObservations.map {
                ($0.provisionalLogicalNodeID, $0)
            }
        )
        let nodeByID = Dictionary(
            uniqueKeysWithValues: result.snapshot.tree.nodes.map {
                ($0.logicalID, $0)
            }
        )
        let directlySelected = Set(result.snapshot.tree.nodes.compactMap {
            node -> LogicalNodeID? in
            guard let observation = observationByNode[node.logicalID] else {
                return nil
            }
            let values = [
                observation.nativeIdentifier.rawValue,
                observation.continuityIdentifier?.rawValue,
            ].compactMap { $0 }
            let semanticKey = semanticKey(for: node)
            return (
                values.contains(where: identifiers.contains)
                    || includedSemanticKeys.contains(semanticKey)
            ) && !excludedSemanticKeys.contains(semanticKey)
                ? node.logicalID
                : nil
        })
        var retained = directlySelected
        for selectedID in directlySelected {
            var parentID = nodeByID[selectedID]?.parentID
            while let current = parentID {
                retained.insert(current)
                parentID = nodeByID[current]?.parentID
            }
        }
        retained.formUnion(result.snapshot.tree.nodes.compactMap {
            $0.permanentRootRole == nil ? nil : $0.logicalID
        })

        let retainedNodes = try normalizedNodes(
            result.snapshot.tree.nodes.filter {
                retained.contains($0.logicalID)
            }
        )
        let retainedIDs = Set(retainedNodes.map(\.logicalID))
        return EndToEndSynchronizationReadResult(
            snapshot: BSESnapshot(
                source: result.snapshot.source,
                capturedAt: result.snapshot.capturedAt,
                tree: try BSETree(nodes: retainedNodes)
            ),
            nativeIdentityObservations:
                result.nativeIdentityObservations.filter {
                    retainedIDs.contains($0.provisionalLogicalNodeID)
                }
        )
    }

    private func semanticKey(for node: BSENode) -> String {
        switch node.kind {
        case .bookmark:
            return "bookmark:\(node.url?.absoluteString ?? "")"
        case .folder:
            return "folder:\(node.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current))"
        }
    }

    private func normalizedNodes(_ nodes: [BSENode]) throws -> [BSENode] {
        let positions = Dictionary(grouping: nodes, by: \.parentID)
            .mapValues { siblings in
                Dictionary(uniqueKeysWithValues: siblings.sorted {
                    if $0.position != $1.position {
                        return $0.position < $1.position
                    }
                    return $0.logicalID < $1.logicalID
                }.enumerated().map { ($0.element.logicalID, $0.offset) })
            }
        return try nodes.map { node in
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
    }
}
