//
//  SynchronizationPlanConsistencyValidator.swift
//  BookmarkBridge
//

import Foundation

/// Applies an immutable synchronization plan to a browser-neutral temporary
/// tree. No adapter or filesystem is reachable from this validation boundary.
nonisolated struct SynchronizationPlanConsistencyValidator: Sendable {
    func validate(
        plan: SynchronizationPlan,
        request: SynchronizationPlanningRequest
    ) throws {
        let predicted = try SynchronizationPlanModel.predicted(request: request)
        var executed = try SynchronizationPlanModel(graph: request.before)
        var firstOperationByParent: [LogicalNodeID?: Int] = [:]

        for (index, operation) in plan.operations.enumerated() {
            let affectedParents = executed.affectedParents(for: operation)
            for parentID in affectedParents where firstOperationByParent[parentID] == nil {
                firstOperationByParent[parentID] = index
            }
            do {
                try executed.apply(operation)
            } catch {
                throw SynchronizationPlanningError.executionPlanDiverged(
                    operationIndex: index,
                    logicalNodeID: operation.logicalNodeID
                )
            }
        }

        guard let mismatch = executed.firstMismatch(comparedWith: predicted) else {
            return
        }
        let firstRelevantIndex = plan.operations.firstIndex {
            $0.logicalNodeID == mismatch.logicalNodeID
        } ?? firstOperationByParent[mismatch.parentID]
        throw SynchronizationPlanningError.executionPlanDiverged(
            operationIndex: firstRelevantIndex,
            logicalNodeID: mismatch.logicalNodeID
        )
    }
}

/// Rewrites structural insertion indices against the exact intermediate tree,
/// then adds only the reorders required to make surviving siblings equal the
/// projected order. Deletions remain in cleanup.
nonisolated struct ExecutableSynchronizationStructureBuilder: Sendable {
    let before: LogicalStateGraph
    let predicted: SynchronizationPlanModel

    func build(
        creations: [SynchronizationOperation],
        structuralOperations: [SynchronizationOperation]
    ) throws -> (
        preparation: [SynchronizationOperation],
        structural: [SynchronizationOperation]
    ) {
        var state = try SynchronizationPlanModel(graph: before)
        var resolvedCreations: [SynchronizationOperation] = []
        var resolvedStructural: [SynchronizationOperation] = []

        for operation in creations {
            guard case .create(let create) = operation else {
                throw SynchronizationPlanningError.inconsistentPlan
            }
            let resolvedPosition = try state.insertionPosition(
                for: create.logicalNodeID,
                parentID: create.parentID,
                predicted: predicted
            )
            let resolved = SynchronizationOperation.create(CreateNodeOperation(
                logicalNodeID: create.logicalNodeID,
                kind: create.kind,
                title: create.title,
                url: create.url,
                parentID: create.parentID,
                position: resolvedPosition
            ))
            try state.apply(resolved)
            resolvedCreations.append(resolved)
        }

        for operation in structuralOperations {
            guard case .move(let move) = operation else { continue }
            let resolved = SynchronizationOperation.move(MoveNodeOperation(
                logicalNodeID: move.logicalNodeID,
                parentID: move.parentID,
                position: try state.insertionPosition(
                    for: move.logicalNodeID,
                    parentID: move.parentID,
                    predicted: predicted
                )
            ))
            try state.apply(resolved)
            resolvedStructural.append(resolved)
        }

        for parentID in predicted.parentIDs {
            let desired = predicted.children(of: parentID)
            var previousID: LogicalNodeID?
            for logicalNodeID in desired {
                defer { previousID = logicalNodeID }
                guard let previousID else { continue }
                let current = state.children(of: parentID)
                guard let currentIndex = current.firstIndex(of: logicalNodeID),
                      let previousIndex = current.firstIndex(of: previousID),
                      currentIndex < previousIndex else {
                    continue
                }
                let operation = SynchronizationOperation.reorder(
                    ReorderNodeOperation(
                        logicalNodeID: logicalNodeID,
                        position: previousIndex
                    )
                )
                try state.apply(operation)
                resolvedStructural.append(operation)
            }
        }

        return (resolvedCreations, resolvedStructural)
    }
}

nonisolated struct SynchronizationPlanModel: Sendable {
    private struct Node: Hashable, Sendable {
        let logicalNodeID: LogicalNodeID
        var kind: NodeKind
        let permanentRootRole: PermanentRootRole?
        var title: String
        var url: URL?
        var parentID: LogicalNodeID?
        var position: Int
        var lifecycle: LogicalNodeLifecycle
    }

    struct Mismatch: Sendable {
        let logicalNodeID: LogicalNodeID
        let parentID: LogicalNodeID?
    }

    private var nodesByID: [LogicalNodeID: Node]
    private var childrenByParent: [LogicalNodeID?: [LogicalNodeID]]

    init(graph: LogicalStateGraph) throws {
        var nodes: [LogicalNodeID: Node] = [:]
        for source in graph.nodes {
            guard let kind = source.kind,
                  let title = source.title,
                  let position = source.position else {
                continue
            }
            nodes[source.logicalNodeID] = Node(
                logicalNodeID: source.logicalNodeID,
                kind: kind,
                permanentRootRole: source.permanentRootRole,
                title: title,
                url: source.url,
                parentID: source.parentID,
                position: position,
                lifecycle: source.lifecycle
            )
        }
        nodesByID = nodes
        childrenByParent = [:]
        try rebuildChildren()
    }

    static func predicted(
        request: SynchronizationPlanningRequest
    ) throws -> SynchronizationPlanModel {
        var result = try SynchronizationPlanModel(graph: request.before)
        let includedChanges = request.logicalDiff.changes.filter {
            includes($0, policy: request.policy)
        }.sorted(by: predictedChangeOrder)
        for change in includedChanges {
            try result.applyPredicted(change, policy: request.policy)
        }
        try result.rebuildChildren()
        return result
    }

    var parentIDs: [LogicalNodeID?] {
        childrenByParent.keys.sorted(by: Self.optionalLogicalIDOrder)
    }

    func children(of parentID: LogicalNodeID?) -> [LogicalNodeID] {
        childrenByParent[parentID, default: []]
    }

    func affectedParents(
        for operation: SynchronizationOperation
    ) -> Set<LogicalNodeID?> {
        switch operation {
        case .create(let create):
            [create.parentID]
        case .delete(let delete):
            [nodesByID[delete.logicalNodeID]?.parentID]
        case .move(let move):
            [nodesByID[move.logicalNodeID]?.parentID, move.parentID]
        case .reorder(let reorder):
            [nodesByID[reorder.logicalNodeID]?.parentID]
        case .rename, .updateURL, .archive:
            []
        }
    }

    func insertionPosition(
        for logicalNodeID: LogicalNodeID,
        parentID: LogicalNodeID?,
        predicted: SynchronizationPlanModel
    ) throws -> Int {
        let desired = predicted.children(of: parentID)
        guard let desiredIndex = desired.firstIndex(of: logicalNodeID) else {
            throw SynchronizationPlanningError.inconsistentPlan
        }
        let current = children(of: parentID).filter { $0 != logicalNodeID }
        for predecessor in desired[..<desiredIndex].reversed() {
            if let index = current.firstIndex(of: predecessor) {
                return index + 1
            }
        }
        for successor in desired[desired.index(after: desiredIndex)...] {
            if let index = current.firstIndex(of: successor) {
                return index
            }
        }
        return current.count
    }

    mutating func apply(_ operation: SynchronizationOperation) throws {
        switch operation {
        case .create(let create):
            guard nodesByID[create.logicalNodeID] == nil,
                  create.parentID.map({ nodesByID[$0]?.kind == .folder }) ?? true else {
                throw SynchronizationPlanningError.inconsistentPlan
            }
            let node = Node(
                logicalNodeID: create.logicalNodeID,
                kind: create.kind,
                permanentRootRole: nil,
                title: create.title,
                url: create.url,
                parentID: create.parentID,
                position: create.position,
                lifecycle: .unregistered
            )
            try insert(node, position: create.position)
        case .delete(let delete):
            guard let node = nodesByID[delete.logicalNodeID],
                  node.permanentRootRole == nil,
                  children(of: delete.logicalNodeID).isEmpty else {
                throw SynchronizationPlanningError.inconsistentPlan
            }
            removeFromParent(delete.logicalNodeID, parentID: node.parentID)
            nodesByID.removeValue(forKey: delete.logicalNodeID)
            childrenByParent.removeValue(forKey: delete.logicalNodeID)
        case .rename(let rename):
            guard nodesByID[rename.logicalNodeID] != nil else {
                throw SynchronizationPlanningError.inconsistentPlan
            }
            nodesByID[rename.logicalNodeID]?.title = rename.title
        case .updateURL(let update):
            guard nodesByID[update.logicalNodeID]?.kind == .bookmark else {
                throw SynchronizationPlanningError.inconsistentPlan
            }
            nodesByID[update.logicalNodeID]?.url = update.url
        case .move(let move):
            try relocate(
                move.logicalNodeID,
                parentID: move.parentID,
                position: move.position
            )
        case .reorder(let reorder):
            guard let node = nodesByID[reorder.logicalNodeID] else {
                throw SynchronizationPlanningError.inconsistentPlan
            }
            try relocate(
                reorder.logicalNodeID,
                parentID: node.parentID,
                position: reorder.position
            )
        case .archive(let archive):
            guard nodesByID[archive.logicalNodeID] != nil else {
                throw SynchronizationPlanningError.inconsistentPlan
            }
            nodesByID[archive.logicalNodeID]?.lifecycle = .registered(
                archive.state
            )
        }
    }

    func firstMismatch(
        comparedWith other: SynchronizationPlanModel
    ) -> Mismatch? {
        let allIDs = Set(nodesByID.keys).union(other.nodesByID.keys).sorted()
        for logicalNodeID in allIDs {
            guard nodesByID[logicalNodeID] == other.nodesByID[logicalNodeID] else {
                return Mismatch(
                    logicalNodeID: logicalNodeID,
                    parentID: other.nodesByID[logicalNodeID]?.parentID
                        ?? nodesByID[logicalNodeID]?.parentID
                )
            }
        }
        return nil
    }

    private mutating func applyPredicted(
        _ change: LogicalChange,
        policy: SynchronizationPolicy
    ) throws {
        switch change {
        case .created(let created):
            guard let kind = created.after.kind,
                  let title = created.after.title,
                  let position = created.after.position else {
                throw SynchronizationPlanningError.invalidLogicalDiff
            }
            nodesByID[created.logicalNodeID] = Node(
                logicalNodeID: created.logicalNodeID,
                kind: kind,
                permanentRootRole: created.after.permanentRootRole,
                title: title,
                url: created.after.url,
                parentID: created.after.parentID,
                position: position,
                lifecycle: created.after.lifecycle
            )
        case .deleted(let deleted):
            nodesByID.removeValue(forKey: deleted.logicalNodeID)
        case .renamed(let renamed):
            guard let title = renamed.after,
                  nodesByID[renamed.logicalNodeID] != nil else {
                throw SynchronizationPlanningError.invalidLogicalDiff
            }
            nodesByID[renamed.logicalNodeID]?.title = title
        case .urlChanged(let changed):
            guard let url = changed.after,
                  nodesByID[changed.logicalNodeID] != nil else {
                throw SynchronizationPlanningError.invalidLogicalDiff
            }
            nodesByID[changed.logicalNodeID]?.url = url
        case .moved(let moved):
            guard nodesByID[moved.logicalNodeID] != nil else {
                throw SynchronizationPlanningError.invalidLogicalDiff
            }
            nodesByID[moved.logicalNodeID]?.parentID = moved.after
        case .reordered(let reordered):
            guard let position = reordered.after,
                  nodesByID[reordered.logicalNodeID] != nil else {
                throw SynchronizationPlanningError.invalidLogicalDiff
            }
            nodesByID[reordered.logicalNodeID]?.position = position
        case .lifecycleChanged(let lifecycle):
            guard nodesByID[lifecycle.logicalNodeID] != nil else {
                throw SynchronizationPlanningError.invalidLogicalDiff
            }
            if lifecycle.after == .registered(.deleted) {
                switch policy.deletedLifecycleHandling {
                case .delete:
                    nodesByID.removeValue(forKey: lifecycle.logicalNodeID)
                case .archive:
                    nodesByID[lifecycle.logicalNodeID]?.lifecycle =
                        .registered(.archived)
                case .reject:
                    throw SynchronizationPlanningError.unsupportedChange(
                        lifecycle.logicalNodeID
                    )
                }
            } else {
                nodesByID[lifecycle.logicalNodeID]?.lifecycle =
                    lifecycle.after
            }
        }
    }

    private mutating func relocate(
        _ logicalNodeID: LogicalNodeID,
        parentID: LogicalNodeID?,
        position: Int
    ) throws {
        guard let node = nodesByID[logicalNodeID],
              node.permanentRootRole == nil,
              parentID.map({ nodesByID[$0]?.kind == .folder }) ?? true else {
            throw SynchronizationPlanningError.inconsistentPlan
        }
        var ancestor = parentID
        while let ancestorID = ancestor {
            guard ancestorID != logicalNodeID else {
                throw SynchronizationPlanningError.inconsistentPlan
            }
            ancestor = nodesByID[ancestorID]?.parentID
        }
        removeFromParent(logicalNodeID, parentID: node.parentID)
        nodesByID[logicalNodeID]?.parentID = parentID
        guard position >= 0,
              position <= childrenByParent[parentID, default: []].count else {
            throw SynchronizationPlanningError.inconsistentPlan
        }
        childrenByParent[parentID, default: []].insert(
            logicalNodeID,
            at: position
        )
        updatePositions(parentID: parentID)
    }

    private mutating func insert(_ node: Node, position: Int) throws {
        guard position >= 0,
              position <= childrenByParent[node.parentID, default: []].count else {
            throw SynchronizationPlanningError.inconsistentPlan
        }
        nodesByID[node.logicalNodeID] = node
        childrenByParent[node.parentID, default: []].insert(
            node.logicalNodeID,
            at: position
        )
        updatePositions(parentID: node.parentID)
    }

    private mutating func removeFromParent(
        _ logicalNodeID: LogicalNodeID,
        parentID: LogicalNodeID?
    ) {
        childrenByParent[parentID, default: []].removeAll {
            $0 == logicalNodeID
        }
        updatePositions(parentID: parentID)
    }

    private mutating func updatePositions(parentID: LogicalNodeID?) {
        for (position, logicalNodeID) in childrenByParent[
            parentID,
            default: []
        ].enumerated() {
            nodesByID[logicalNodeID]?.position = position
        }
    }

    private mutating func rebuildChildren() throws {
        var grouped: [LogicalNodeID?: [Node]] = [:]
        for node in nodesByID.values {
            if let parentID = node.parentID,
               nodesByID[parentID]?.kind != .folder {
                throw SynchronizationPlanningError.inconsistentPlan
            }
            grouped[node.parentID, default: []].append(node)
        }
        childrenByParent = [:]
        for (parentID, nodes) in grouped {
            let ordered = nodes.sorted {
                if $0.position != $1.position {
                    return $0.position < $1.position
                }
                return $0.logicalNodeID < $1.logicalNodeID
            }
            childrenByParent[parentID] = ordered.map(\.logicalNodeID)
            for (position, node) in ordered.enumerated() {
                nodesByID[node.logicalNodeID]?.position = position
            }
        }
    }

    private static func includes(
        _ change: LogicalChange,
        policy: SynchronizationPolicy
    ) -> Bool {
        switch policy.changeSelection {
        case .allChanges:
            true
        case .additionsOnly:
            if case .created = change { true } else { false }
        case .contentOnly:
            switch change {
            case .renamed, .urlChanged: true
            default: false
            }
        }
    }

    private static func predictedChangeOrder(
        _ lhs: LogicalChange,
        _ rhs: LogicalChange
    ) -> Bool {
        func rank(_ change: LogicalChange) -> Int {
            switch change {
            case .created: 0
            case .moved: 1
            case .reordered: 2
            case .renamed: 3
            case .urlChanged: 4
            case .lifecycleChanged: 5
            case .deleted: 6
            }
        }
        let lhsRank = rank(lhs)
        let rhsRank = rank(rhs)
        if lhsRank != rhsRank { return lhsRank < rhsRank }
        return lhs.logicalNodeID < rhs.logicalNodeID
    }

    private static func optionalLogicalIDOrder(
        _ lhs: LogicalNodeID?,
        _ rhs: LogicalNodeID?
    ) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil): false
        case (nil, _): true
        case (_, nil): false
        case (.some(let lhs), .some(let rhs)): lhs < rhs
        }
    }
}
