//
//  LogicalSnapshotBuilder.swift
//  BookmarkBridge
//

/// Builder boundary injected into the engine.
nonisolated protocol LogicalSnapshotBuilding: Sendable {
    func build(
        from snapshot: BSESnapshot,
        assignments: [LogicalIdentityAssignment]
    ) throws -> LogicalSnapshot
}

/// Rebuilds a tree by applying supplied IDs. It makes no identity decision.
nonisolated struct LogicalSnapshotBuilder: LogicalSnapshotBuilding {
    func build(
        from snapshot: BSESnapshot,
        assignments: [LogicalIdentityAssignment]
    ) throws -> LogicalSnapshot {
        guard assignments.allSatisfy({ $0.sourceID == snapshot.source }) else {
            throw IdentityReconciliationError.assignmentSourceMismatch(snapshot.source)
        }
        let mapping = try mappingByProvisionalID(assignments)
        let provisionalIDs = Set(snapshot.tree.nodes.map(\.logicalID))
        guard Set(mapping.keys) == provisionalIDs else {
            throw IdentityReconciliationError.incompleteAssignments(snapshot.source)
        }
        guard Set(mapping.values).count == mapping.values.count else {
            throw IdentityReconciliationError.duplicateLogicalIdentity(snapshot.source)
        }

        let nodes: [BSENode]
        do {
            nodes = try snapshot.tree.nodes.map { node in
                guard let logicalID = mapping[node.logicalID] else {
                    throw IdentityReconciliationError.incompleteAssignments(snapshot.source)
                }
                let parentID: LogicalNodeID?
                if let provisionalParentID = node.parentID {
                    guard let mappedParentID = mapping[provisionalParentID] else {
                        throw IdentityReconciliationError.incompleteAssignments(snapshot.source)
                    }
                    parentID = mappedParentID
                } else {
                    parentID = nil
                }
                return try BSENode(
                    logicalID: logicalID,
                    kind: node.kind,
                    title: node.title,
                    parentID: parentID,
                    position: node.position,
                    url: node.url
                )
            }
        } catch let error as IdentityReconciliationError {
            throw error
        } catch {
            throw IdentityReconciliationError.invalidLogicalSnapshot(snapshot.source)
        }

        do {
            return LogicalSnapshot(
                source: snapshot.source,
                capturedAt: snapshot.capturedAt,
                tree: try BSETree(nodes: nodes)
            )
        } catch {
            throw IdentityReconciliationError.invalidLogicalSnapshot(snapshot.source)
        }
    }

    private func mappingByProvisionalID(
        _ assignments: [LogicalIdentityAssignment]
    ) throws -> [LogicalNodeID: LogicalNodeID] {
        var mapping: [LogicalNodeID: LogicalNodeID] = [:]
        for assignment in assignments {
            guard mapping.updateValue(
                assignment.logicalNodeID,
                forKey: assignment.provisionalLogicalID
            ) == nil else {
                throw IdentityReconciliationError.duplicateAssignment(
                    IdentityNodeReference(
                        sourceID: assignment.sourceID,
                        provisionalLogicalID: assignment.provisionalLogicalID
                    )
                )
            }
        }
        return mapping
    }
}
