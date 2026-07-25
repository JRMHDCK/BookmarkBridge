//
//  NativeIdentityResolver.swift
//  BookmarkBridge
//

/// Read-only bridge from native observations to already-known durable IDs.
///
/// It performs no matching, creates no identity, and never mutates the
/// repository. Unknown native identities retain their provisional IDs.
nonisolated struct NativeIdentityResolver: Sendable {
    private let repository: any NativeIdentityRepository

    init(repository: any NativeIdentityRepository) {
        self.repository = repository
    }

    func resolve(
        _ readResult: EndToEndSynchronizationReadResult
    ) throws -> NativeIdentityResolutionResult {
        let snapshot = readResult.snapshot
        let observations = try observationIndex(
            readResult.nativeIdentityObservations,
            sourceID: snapshot.source,
            nodeIDs: Set(snapshot.tree.nodes.map(\.logicalID))
        )

        var resolvedIDs: [LogicalNodeID: LogicalNodeID] = [:]
        var resolvedCount = 0
        for node in snapshot.tree.nodes {
            guard let observation = observations[node.logicalID] else {
                throw NativeIdentityResolutionError.missingObservation(
                    node.logicalID
                )
            }
            if let durableID = repository.logicalNodeID(
                for: observation.nativeIdentifier,
                sourceID: snapshot.source
            ) ?? observation.continuityIdentifier.flatMap({
                repository.logicalNodeID(
                    for: $0,
                    sourceID: snapshot.source
                )
            }) {
                resolvedIDs[node.logicalID] = durableID
                resolvedCount += 1
            } else {
                resolvedIDs[node.logicalID] = node.logicalID
            }
        }
        guard Set(resolvedIDs.values).count == resolvedIDs.count else {
            let duplicate = Dictionary(
                grouping: resolvedIDs.values,
                by: { $0 }
            )
                .filter { $0.value.count > 1 }
                .keys
                .sorted()
                .first
            guard let duplicate else {
                throw NativeIdentityResolutionError.invalidResolvedSnapshot(
                    snapshot.source
                )
            }
            throw NativeIdentityResolutionError
                .duplicateResolvedLogicalNodeID(duplicate)
        }

        let nodes: [BSENode]
        do {
            nodes = try snapshot.tree.nodes.map { node in
                guard let logicalID = resolvedIDs[node.logicalID] else {
                    throw NativeIdentityResolutionError.missingObservation(
                        node.logicalID
                    )
                }
                let parentID: LogicalNodeID?
                if let provisionalParentID = node.parentID {
                    guard let resolvedParentID = resolvedIDs[
                        provisionalParentID
                    ] else {
                        throw NativeIdentityResolutionError.missingObservation(
                            provisionalParentID
                        )
                    }
                    parentID = resolvedParentID
                } else {
                    parentID = nil
                }
                return try BSENode(
                    logicalID: logicalID,
                    kind: node.kind,
                    permanentRootRole: node.permanentRootRole,
                    title: node.title,
                    parentID: parentID,
                    position: node.position,
                    url: node.url
                )
            }
        } catch let error as NativeIdentityResolutionError {
            throw error
        } catch {
            throw NativeIdentityResolutionError.invalidResolvedSnapshot(
                snapshot.source
            )
        }

        let resolvedTree: BSETree
        do {
            resolvedTree = try BSETree(nodes: nodes)
        } catch {
            throw NativeIdentityResolutionError.invalidResolvedSnapshot(
                snapshot.source
            )
        }
        let resolvedObservations = try readResult.nativeIdentityObservations
            .map { observation in
                guard let logicalID = resolvedIDs[
                    observation.provisionalLogicalNodeID
                ] else {
                    throw NativeIdentityResolutionError.orphanObservation(
                        observation.provisionalLogicalNodeID
                    )
                }
                return NativeIdentityObservation(
                    sourceID: observation.sourceID,
                    provisionalLogicalNodeID: logicalID,
                    nativeIdentifier: observation.nativeIdentifier,
                    nativeIdentityKind: observation.nativeIdentityKind,
                    continuityIdentifier: observation.continuityIdentifier,
                    continuityIdentityKind:
                        observation.continuityIdentityKind
                )
            }

        return NativeIdentityResolutionResult(
            readResult: EndToEndSynchronizationReadResult(
                snapshot: BSESnapshot(
                    source: snapshot.source,
                    capturedAt: snapshot.capturedAt,
                    tree: resolvedTree
                ),
                nativeIdentityObservations: resolvedObservations
            ),
            resolvedIdentityCount: resolvedCount,
            unresolvedIdentityCount: nodes.count - resolvedCount
        )
    }

    private func observationIndex(
        _ observations: [NativeIdentityObservation],
        sourceID: BSESourceID,
        nodeIDs: Set<LogicalNodeID>
    ) throws -> [LogicalNodeID: NativeIdentityObservation] {
        var result: [LogicalNodeID: NativeIdentityObservation] = [:]
        for observation in observations {
            guard observation.sourceID == sourceID else {
                throw NativeIdentityResolutionError
                    .observationSourceMismatch(
                        expected: sourceID,
                        actual: observation.sourceID
                    )
            }
            guard nodeIDs.contains(observation.provisionalLogicalNodeID) else {
                throw NativeIdentityResolutionError.orphanObservation(
                    observation.provisionalLogicalNodeID
                )
            }
            guard result.updateValue(
                observation,
                forKey: observation.provisionalLogicalNodeID
            ) == nil else {
                throw NativeIdentityResolutionError.duplicateObservation(
                    observation.provisionalLogicalNodeID
                )
            }
        }
        return result
    }
}
