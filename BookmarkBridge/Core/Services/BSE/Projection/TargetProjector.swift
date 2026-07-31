//
//  TargetProjector.swift
//  BookmarkBridge
//

/// Pure source-to-target projection. It builds graph values only; policy
/// execution and lifecycle handling remain responsibilities of later stages.
nonisolated struct TargetProjector: Sendable {
    init() {}

    func project(request: ProjectionRequest) throws -> TargetProjection {
        let rootContext = try PermanentRootProjectionContext(request: request)
        let before = try makeGraph(
            projectedNodes: request.targetSnapshot.tree.nodes.map {
                ProjectedNode(
                    node: $0,
                    observations: [observation(
                        node: $0,
                        snapshot: request.targetSnapshot
                    )]
                )
            }
        )

        let afterNodes: [ProjectedNode]
        switch request.policy.changeSelection {
        case .allChanges:
            afterNodes = request.sourceSnapshot.tree.nodes.map {
                ProjectedNode(
                    node: $0,
                    observations: [observation(
                        node: $0,
                        snapshot: request.sourceSnapshot
                    )]
                )
            }
        case .additionsOnly:
            afterNodes = try additionsOnlyNodes(request: request)
        case .contentOnly:
            afterNodes = try contentOnlyNodes(request: request)
        }
        let protectedAfterNodes = try rootContext.protect(
            afterNodes,
            sourceSnapshot: request.sourceSnapshot,
            targetSnapshot: request.targetSnapshot
        )
        let finalAfterNodes: [ProjectedNode]
        switch request.policy.changeSelection {
        case .allChanges, .additionsOnly:
            finalAfterNodes = try normalizeChildPositions(
                protectedAfterNodes
            )
        case .contentOnly:
            finalAfterNodes = protectedAfterNodes
        }

        return try TargetProjection(
            before: before,
            after: makeGraph(projectedNodes: finalAfterNodes)
        )
    }

    /// Projection can remove or replace browser-specific subtrees while
    /// retaining the source nodes' raw sibling indices. Positions in the
    /// projected universal graph are ranks among the children that remain.
    private func normalizeChildPositions(
        _ projectedNodes: [ProjectedNode]
    ) throws -> [ProjectedNode] {
        let groups = Dictionary(grouping: projectedNodes) {
            $0.node.parentID
        }
        var result: [ProjectedNode] = []
        result.reserveCapacity(projectedNodes.count)
        for parentID in groups.keys.sorted(by: optionalLogicalIDOrder) {
            let siblings = groups[parentID, default: []].sorted {
                if $0.node.position != $1.node.position {
                    return $0.node.position < $1.node.position
                }
                return $0.node.logicalID < $1.node.logicalID
            }
            guard parentID != nil else {
                result.append(contentsOf: siblings)
                continue
            }
            for (position, projected) in siblings.enumerated() {
                guard projected.node.position != position else {
                    result.append(projected)
                    continue
                }
                let node: BSENode
                do {
                    node = try BSENode(
                        logicalID: projected.node.logicalID,
                        kind: projected.node.kind,
                        permanentRootRole: projected.node.permanentRootRole,
                        title: projected.node.title,
                        parentID: projected.node.parentID,
                        position: position,
                        url: projected.node.url
                    )
                } catch {
                    throw TargetProjectionError.projectionImpossible(
                        projected.node.logicalID
                    )
                }
                result.append(ProjectedNode(
                    node: node,
                    observations: projected.observations
                ))
            }
        }
        return result
    }

    private func additionsOnlyNodes(
        request: ProjectionRequest
    ) throws -> [ProjectedNode] {
        let targetIDs = Set(request.targetSnapshot.tree.nodes.map(\.logicalID))
        let targetNodes = request.targetSnapshot.tree.nodes.map {
            ProjectedNode(
                node: $0,
                observations: [observation(
                    node: $0,
                    snapshot: request.targetSnapshot
                )]
            )
        }
        let sourceAdditions = request.sourceSnapshot.tree.nodes
            .filter { !targetIDs.contains($0.logicalID) }
        let existingChildCounts = Dictionary(
            grouping: request.targetSnapshot.tree.nodes,
            by: \.parentID
        ).mapValues(\.count)
        let additionsByParent = Dictionary(
            grouping: sourceAdditions,
            by: \.parentID
        )
        var projectedAdditions: [ProjectedNode] = []
        projectedAdditions.reserveCapacity(sourceAdditions.count)

        for parentID in additionsByParent.keys.sorted(by: optionalLogicalIDOrder) {
            let siblings = additionsByParent[parentID, default: []].sorted {
                if $0.position != $1.position {
                    return $0.position < $1.position
                }
                return $0.logicalID < $1.logicalID
            }
            let startingPosition = existingChildCounts[parentID, default: 0]
            for (offset, sourceNode) in siblings.enumerated() {
                let node: BSENode
                do {
                    node = try BSENode(
                        logicalID: sourceNode.logicalID,
                        kind: sourceNode.kind,
                        permanentRootRole: sourceNode.permanentRootRole,
                        title: sourceNode.title,
                        parentID: sourceNode.parentID,
                        position: startingPosition + offset,
                        url: sourceNode.url
                    )
                } catch {
                    throw TargetProjectionError.projectionImpossible(
                        sourceNode.logicalID
                    )
                }
                projectedAdditions.append(ProjectedNode(
                    node: node,
                    observations: [observation(
                        node: sourceNode,
                        snapshot: request.sourceSnapshot
                    )]
                ))
            }
        }
        return targetNodes + projectedAdditions
    }

    private func optionalLogicalIDOrder(
        _ lhs: LogicalNodeID?,
        _ rhs: LogicalNodeID?
    ) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            false
        case (nil, _):
            true
        case (_, nil):
            false
        case (.some(let lhs), .some(let rhs)):
            lhs < rhs
        }
    }

    private func contentOnlyNodes(
        request: ProjectionRequest
    ) throws -> [ProjectedNode] {
        let sourceNodes = Dictionary(
            uniqueKeysWithValues: request.sourceSnapshot.tree.nodes.map {
                ($0.logicalID, $0)
            }
        )
        return try request.targetSnapshot.tree.nodes.map { targetNode in
            guard let sourceNode = sourceNodes[targetNode.logicalID] else {
                return ProjectedNode(
                    node: targetNode,
                    observations: [observation(
                        node: targetNode,
                        snapshot: request.targetSnapshot
                    )]
                )
            }
            guard sourceNode.kind == targetNode.kind else {
                throw TargetProjectionError.projectionImpossible(
                    targetNode.logicalID
                )
            }
            if targetNode.permanentRootRole != nil {
                guard sourceNode.permanentRootRole
                        == targetNode.permanentRootRole else {
                    throw TargetProjectionError.invalidPermanentRootMutation(
                        targetNode.logicalID
                    )
                }
                return ProjectedNode(
                    node: targetNode,
                    observations: [
                        observation(
                            node: targetNode,
                            snapshot: request.targetSnapshot
                        ),
                        observation(
                            node: sourceNode,
                            snapshot: request.sourceSnapshot
                        )
                    ]
                )
            }
            let projectedNode: BSENode
            do {
                projectedNode = try BSENode(
                    logicalID: targetNode.logicalID,
                    kind: targetNode.kind,
                    permanentRootRole: targetNode.permanentRootRole,
                    title: sourceNode.title,
                    parentID: targetNode.parentID,
                    position: targetNode.position,
                    url: sourceNode.url
                )
            } catch {
                throw TargetProjectionError.projectionImpossible(
                    targetNode.logicalID
                )
            }
            return ProjectedNode(
                node: projectedNode,
                observations: [
                    observation(
                        node: targetNode,
                        snapshot: request.targetSnapshot
                    ),
                    observation(
                        node: sourceNode,
                        snapshot: request.sourceSnapshot
                    )
                ]
            )
        }
    }

    private func makeGraph(
        projectedNodes: [ProjectedNode]
    ) throws -> LogicalStateGraph {
        try validate(projectedNodes)
        let states: [LogicalNodeState]
        do {
            states = try projectedNodes.map { projected in
                try LogicalNodeState(
                    logicalNodeID: projected.node.logicalID,
                    kind: projected.node.kind,
                    permanentRootRole: projected.node.permanentRootRole,
                    title: projected.node.title,
                    url: projected.node.url,
                    parentID: projected.node.parentID,
                    position: projected.node.position,
                    lifecycle: .unregistered,
                    observations: projected.observations
                )
            }
        } catch let error as LogicalStateBuildingError {
            throw map(error)
        } catch {
            throw TargetProjectionError.invalidGraph(nil)
        }

        let observationCount = states.reduce(0) {
            $0 + $1.observations.count
        }
        let snapshotNodeCount = states.reduce(0) { count, state in
            count + state.observations.filter {
                $0.snapshotNode != nil
            }.count
        }
        let sourceCount = Set(
            states.flatMap(\.observations).map(\.sourceID)
        ).count
        let report = LogicalStateBuildingReport(
            baselineIdentityCount: 0,
            snapshotCount: sourceCount,
            snapshotNodeCount: snapshotNodeCount,
            logicalNodeCount: states.count,
            structurallyAvailableNodeCount: states.count,
            baselineOnlyNodeCount: 0,
            unregisteredNodeCount: states.count,
            observationCount: observationCount
        )
        do {
            return try LogicalStateGraph(nodes: states, report: report)
        } catch let error as LogicalStateBuildingError {
            throw map(error)
        } catch {
            throw TargetProjectionError.invalidGraph(nil)
        }
    }

    private func validate(_ projectedNodes: [ProjectedNode]) throws {
        var index: [LogicalNodeID: BSENode] = [:]
        for projected in projectedNodes {
            guard index.updateValue(
                projected.node,
                forKey: projected.node.logicalID
            ) == nil else {
                throw TargetProjectionError.invalidGraph(
                    projected.node.logicalID
                )
            }
        }
        for node in index.values {
            guard let parentID = node.parentID else { continue }
            guard let parent = index[parentID] else {
                throw TargetProjectionError.parentAbsent(
                    logicalNodeID: node.logicalID,
                    parentID: parentID
                )
            }
            guard parent.kind == .folder else {
                throw TargetProjectionError.projectionImpossible(
                    node.logicalID
                )
            }
        }

        enum VisitState {
            case visiting
            case visited
        }
        var visitStates: [LogicalNodeID: VisitState] = [:]
        func visit(_ logicalNodeID: LogicalNodeID) throws {
            switch visitStates[logicalNodeID] {
            case .visiting:
                throw TargetProjectionError.cycle(logicalNodeID)
            case .visited:
                return
            case nil:
                break
            }
            visitStates[logicalNodeID] = .visiting
            if let parentID = index[logicalNodeID]?.parentID {
                try visit(parentID)
            }
            visitStates[logicalNodeID] = .visited
        }
        for logicalNodeID in index.keys.sorted() {
            try visit(logicalNodeID)
        }
    }

    private func observation(
        node: BSENode,
        snapshot: LogicalSnapshot
    ) -> LogicalNodeStateObservation {
        LogicalNodeStateObservation(
            sourceID: snapshot.source,
            snapshotCapturedAt: snapshot.capturedAt,
            snapshotNode: node,
            baselineObservation: nil
        )
    }

    private func map(
        _ error: LogicalStateBuildingError
    ) -> TargetProjectionError {
        switch error {
        case .missingParent(let logicalNodeID, let parentID):
            .parentAbsent(
                logicalNodeID: logicalNodeID,
                parentID: parentID
            )
        case .inconsistentGraph(let logicalNodeID),
             .duplicateLogicalNode(let logicalNodeID, _):
            .invalidGraph(logicalNodeID)
        case .invalidBaseline, .invalidLogicalSnapshot:
            .invalidGraph(nil)
        }
    }

    private struct ProjectedNode {
        let node: BSENode
        let observations: [LogicalNodeStateObservation]
    }

    private struct PermanentRootProjectionContext {
        private let sourceNodes: [BSENode]
        private let targetNodes: [BSENode]
        private let sourceRootsByRole: [PermanentRootRole: BSENode]
        private let targetRootsByRole: [PermanentRootRole: BSENode]

        init(request: ProjectionRequest) throws {
            sourceNodes = request.sourceSnapshot.tree.nodes
            targetNodes = request.targetSnapshot.tree.nodes
            sourceRootsByRole = try Self.rootsByRole(sourceNodes)
            targetRootsByRole = try Self.rootsByRole(targetNodes)

            let sharedRoles = Set(sourceRootsByRole.keys)
                .intersection(targetRootsByRole.keys)
            for role in sharedRoles {
                guard let sourceRoot = sourceRootsByRole[role],
                      let targetRoot = targetRootsByRole[role] else {
                    throw TargetProjectionError.invalidGraph(nil)
                }
                guard sourceRoot.logicalID == targetRoot.logicalID else {
                    throw TargetProjectionError.invalidPermanentRootMutation(
                        sourceRoot.logicalID
                    )
                }
            }

            let sourceByID = Dictionary(
                uniqueKeysWithValues: sourceNodes.map { ($0.logicalID, $0) }
            )
            let targetByID = Dictionary(
                uniqueKeysWithValues: targetNodes.map { ($0.logicalID, $0) }
            )
            for logicalNodeID in Set(sourceByID.keys).intersection(targetByID.keys) {
                guard sourceByID[logicalNodeID]?.permanentRootRole
                        == targetByID[logicalNodeID]?.permanentRootRole else {
                    throw TargetProjectionError.invalidPermanentRootMutation(
                        logicalNodeID
                    )
                }
            }
        }

        func protect(
            _ projectedNodes: [ProjectedNode],
            sourceSnapshot: LogicalSnapshot,
            targetSnapshot: LogicalSnapshot
        ) throws -> [ProjectedNode] {
            let sourceExclusiveRoles = Set(sourceRootsByRole.keys)
                .subtracting(targetRootsByRole.keys)
            let targetExclusiveRoles = Set(targetRootsByRole.keys)
                .subtracting(sourceRootsByRole.keys)
            let excludedSourceIDs = subtreeIDs(
                rootedAt: sourceExclusiveRoles.compactMap {
                    sourceRootsByRole[$0]?.logicalID
                },
                nodes: sourceNodes
            )
            let retainedTargetIDs = subtreeIDs(
                rootedAt: targetExclusiveRoles.compactMap {
                    targetRootsByRole[$0]?.logicalID
                },
                nodes: targetNodes
            )

            var resultByID = Dictionary(
                uniqueKeysWithValues: projectedNodes
                    .filter { !excludedSourceIDs.contains($0.node.logicalID) }
                    .map { ($0.node.logicalID, $0) }
            )
            let sharedRoles = Set(sourceRootsByRole.keys)
                .intersection(targetRootsByRole.keys)
            for role in sharedRoles {
                guard let sourceRoot = sourceRootsByRole[role],
                      let targetRoot = targetRootsByRole[role] else {
                    continue
                }
                resultByID[targetRoot.logicalID] = ProjectedNode(
                    node: targetRoot,
                    observations: [
                        Self.observation(
                            node: targetRoot,
                            snapshot: targetSnapshot
                        ),
                        Self.observation(
                            node: sourceRoot,
                            snapshot: sourceSnapshot
                        ),
                    ]
                )
            }
            for node in targetNodes where retainedTargetIDs.contains(node.logicalID) {
                resultByID[node.logicalID] = ProjectedNode(
                    node: node,
                    observations: [
                        Self.observation(
                            node: node,
                            snapshot: targetSnapshot
                        )
                    ]
                )
            }
            return resultByID.values.sorted {
                $0.node.logicalID < $1.node.logicalID
            }
        }

        private static func rootsByRole(
            _ nodes: [BSENode]
        ) throws -> [PermanentRootRole: BSENode] {
            var result: [PermanentRootRole: BSENode] = [:]
            for node in nodes {
                guard let role = node.permanentRootRole else { continue }
                guard node.kind == .folder,
                      node.parentID == nil,
                      result.updateValue(node, forKey: role) == nil else {
                    throw TargetProjectionError.invalidPermanentRootMutation(
                        node.logicalID
                    )
                }
            }
            return result
        }

        private func subtreeIDs(
            rootedAt rootIDs: [LogicalNodeID],
            nodes: [BSENode]
        ) -> Set<LogicalNodeID> {
            var childrenByParent: [LogicalNodeID: [LogicalNodeID]] = [:]
            for node in nodes {
                if let parentID = node.parentID {
                    childrenByParent[parentID, default: []].append(
                        node.logicalID
                    )
                }
            }
            var result: Set<LogicalNodeID> = []
            var pending = rootIDs.sorted()
            while let logicalNodeID = pending.popLast() {
                guard result.insert(logicalNodeID).inserted else { continue }
                pending.append(
                    contentsOf: childrenByParent[logicalNodeID] ?? []
                )
            }
            return result
        }

        private static func observation(
            node: BSENode,
            snapshot: LogicalSnapshot
        ) -> LogicalNodeStateObservation {
            LogicalNodeStateObservation(
                sourceID: snapshot.source,
                snapshotCapturedAt: snapshot.capturedAt,
                snapshotNode: node,
                baselineObservation: nil
            )
        }
    }
}
