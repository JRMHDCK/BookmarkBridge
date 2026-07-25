//
//  SynchronizationPlanner.swift
//  BookmarkBridge
//

/// Pure transformation from a validated logical diff to ordered atomic operations.
nonisolated struct SynchronizationPlanner: Sendable {
    init() {}

    func plan(
        request: SynchronizationPlanningRequest
    ) throws -> SynchronizationPlan {
        try validate(request.logicalDiff)
        try validatePermanentRoots(
            request.logicalDiff,
            before: request.before
        )
        let moveTargetPositions = try resolveMoveTargetPositions(
            diff: request.logicalDiff,
            before: request.before,
            policy: request.policy
        )
        var preparation: [SynchronizationOperation] = []
        var structural: [SynchronizationOperation] = []
        var content: [SynchronizationOperation] = []
        var cleanup: [SynchronizationOperation] = []
        var skippedChangeCount = 0

        for change in request.logicalDiff.changes {
            guard includes(change, policy: request.policy) else {
                skippedChangeCount += 1
                continue
            }
            // A move carries the complete structural destination. When the
            // diff also reports a position change, that reorder is consumed
            // here instead of producing a contradictory second mutation.
            if case .reordered = change,
               moveTargetPositions[change.logicalNodeID] != nil {
                continue
            }
            let operation = try makeOperation(
                for: change,
                policy: request.policy,
                moveTargetPositions: moveTargetPositions
            )
            switch operation {
            case .create:
                preparation.append(operation)
            case .move, .reorder:
                structural.append(operation)
            case .rename, .updateURL:
                content.append(operation)
            case .archive, .delete:
                cleanup.append(operation)
            }
        }

        try validatePlan([
            .preparation(preparation),
            .structural(structural),
            .content(content),
            .cleanup(cleanup),
        ])
        preparation = try orderCreateOperations(
            preparation,
            before: request.before
        )
        structural = try orderStructuralOperations(
            structural,
            afterCreating: preparation,
            before: request.before,
            deletedNodeIDs: Set(cleanup.compactMap { operation in
                guard case .delete = operation else { return nil }
                return operation.logicalNodeID
            })
        )
        let positionOrdered = try PositionDependencyScheduler(
            creations: preparation,
            structuralOperations: structural,
            before: request.before
        ).ordered()
        preparation = positionOrdered.preparation
        structural = positionOrdered.structural
        content.sort(by: operationOrder)
        cleanup.sort(by: operationOrder)
        cleanup = try orderDeleteOperations(
            in: cleanup,
            before: request.before
        )
        let phases: [SynchronizationPhase] = [
            .preparation(preparation),
            .structural(structural),
            .content(content),
            .cleanup(cleanup),
        ]
        try validatePlan(phases)
        let operationCount = phases.reduce(0) { $0 + $1.operations.count }
        return SynchronizationPlan(
            phases: phases,
            report: SynchronizationPlanningReport(
                policy: request.policy,
                inputChangeCount: request.logicalDiff.changes.count,
                plannedOperationCount: operationCount,
                skippedChangeCount: skippedChangeCount,
                preparationOperationCount: preparation.count,
                structuralOperationCount: structural.count,
                contentOperationCount: content.count,
                cleanupOperationCount: cleanup.count
            )
        )
    }

    private func validate(_ diff: LogicalDiffResult) throws {
        let counts = DiffCounts(diff.changes)
        guard diff.report.beforeNodeCount >= 0,
              diff.report.afterNodeCount >= 0,
              diff.report.unchangedNodeCount >= 0,
              diff.report.beforeNodeCount - counts.deleted + counts.created
                == diff.report.afterNodeCount,
              diff.report.changeCount == diff.changes.count,
              diff.report.createdCount == counts.created,
              diff.report.deletedCount == counts.deleted,
              diff.report.renamedCount == counts.renamed,
              diff.report.urlChangedCount == counts.urlChanged,
              diff.report.movedCount == counts.moved,
              diff.report.reorderedCount == counts.reordered,
              diff.report.lifecycleChangedCount == counts.lifecycleChanged else {
            throw SynchronizationPlanningError.invalidLogicalDiff
        }
        var keys: Set<ChangeKey> = []
        for change in diff.changes {
            guard keys.insert(ChangeKey(change)).inserted else {
                throw SynchronizationPlanningError.invalidLogicalDiff
            }
        }
    }

    private func includes(
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

    private func validatePermanentRoots(
        _ diff: LogicalDiffResult,
        before: LogicalStateGraph
    ) throws {
        let permanentRootIDs = Set(
            before.nodes.compactMap { node in
                node.permanentRootRole == nil ? nil : node.logicalNodeID
            }
        )
        for change in diff.changes {
            let isPermanentRoot: Bool
            switch change {
            case .created(let created):
                isPermanentRoot = created.after.permanentRootRole != nil
            case .deleted(let deleted):
                isPermanentRoot = deleted.before.permanentRootRole != nil
            case .renamed, .urlChanged, .moved, .reordered,
                 .lifecycleChanged:
                isPermanentRoot = permanentRootIDs.contains(
                    change.logicalNodeID
                )
            }
            if isPermanentRoot {
                throw SynchronizationPlanningError
                    .invalidPermanentRootMutation(change.logicalNodeID)
            }
        }
    }

    private func makeOperation(
        for change: LogicalChange,
        policy: SynchronizationPolicy,
        moveTargetPositions: [LogicalNodeID: Int]
    ) throws -> SynchronizationOperation {
        switch change {
        case .created(let change):
            guard let kind = change.after.kind,
                  let title = change.after.title,
                  let position = change.after.position else {
                throw SynchronizationPlanningError.invalidLogicalDiff
            }
            return .create(CreateNodeOperation(
                logicalNodeID: change.logicalNodeID,
                kind: kind,
                title: title,
                url: change.after.url,
                parentID: change.after.parentID,
                position: position
            ))
        case .deleted(let change):
            return .delete(DeleteNodeOperation(
                logicalNodeID: change.logicalNodeID
            ))
        case .renamed(let change):
            guard let title = change.after else {
                throw SynchronizationPlanningError.invalidLogicalDiff
            }
            return .rename(RenameNodeOperation(
                logicalNodeID: change.logicalNodeID,
                title: title
            ))
        case .urlChanged(let change):
            guard let url = change.after else {
                throw SynchronizationPlanningError.invalidLogicalDiff
            }
            return .updateURL(UpdateURLOperation(
                logicalNodeID: change.logicalNodeID,
                url: url
            ))
        case .moved(let change):
            guard let position = moveTargetPositions[change.logicalNodeID] else {
                throw SynchronizationPlanningError.invalidLogicalDiff
            }
            return .move(MoveNodeOperation(
                logicalNodeID: change.logicalNodeID,
                parentID: change.after,
                position: position
            ))
        case .reordered(let change):
            guard let position = change.after, position >= 0 else {
                throw SynchronizationPlanningError.invalidLogicalDiff
            }
            return .reorder(ReorderNodeOperation(
                logicalNodeID: change.logicalNodeID,
                position: position
            ))
        case .lifecycleChanged(let change):
            guard case .registered(let state) = change.after else {
                throw SynchronizationPlanningError.unsupportedChange(change.logicalNodeID)
            }
            switch state {
            case .archived:
                return .archive(ArchiveNodeOperation(
                    logicalNodeID: change.logicalNodeID,
                    state: .archived
                ))
            case .deleted:
                switch policy.deletedLifecycleHandling {
                case .delete:
                    return .delete(DeleteNodeOperation(
                        logicalNodeID: change.logicalNodeID
                    ))
                case .archive:
                    return .archive(ArchiveNodeOperation(
                        logicalNodeID: change.logicalNodeID,
                        state: .archived
                    ))
                case .reject:
                    throw SynchronizationPlanningError.unsupportedChange(
                        change.logicalNodeID
                    )
                }
            case .active:
                throw SynchronizationPlanningError.unsupportedChange(change.logicalNodeID)
            }
        }
    }

    /// A complete move destination is reconstructed from the exhaustive diff:
    /// an accompanying reorder carries the changed target position; otherwise
    /// the absence of a reorder means the position is unchanged from `before`.
    private func resolveMoveTargetPositions(
        diff: LogicalDiffResult,
        before: LogicalStateGraph,
        policy: SynchronizationPolicy
    ) throws -> [LogicalNodeID: Int] {
        let nodesBefore = Dictionary(
            uniqueKeysWithValues: before.nodes.map { ($0.logicalNodeID, $0) }
        )
        let includedMovedIDs = Set<LogicalNodeID>(diff.changes.compactMap { change in
            guard case .moved(let moved) = change,
                  includes(change, policy: policy) else {
                return nil
            }
            return moved.logicalNodeID
        })
        var reorderedPositions: [LogicalNodeID: Int] = [:]
        for change in diff.changes {
            guard case .reordered(let reordered) = change,
                  includedMovedIDs.contains(reordered.logicalNodeID) else { continue }
            guard let position = reordered.after, position >= 0 else {
                throw SynchronizationPlanningError.invalidLogicalDiff
            }
            reorderedPositions[reordered.logicalNodeID] = position
        }

        var targetPositions: [LogicalNodeID: Int] = [:]
        for change in diff.changes {
            guard case .moved(let moved) = change,
                  includedMovedIDs.contains(moved.logicalNodeID) else { continue }
            let position: Int
            if let reorderedPosition = reorderedPositions[moved.logicalNodeID] {
                position = reorderedPosition
            } else {
                guard let beforePosition = nodesBefore[moved.logicalNodeID]?.position,
                      beforePosition >= 0 else {
                    throw SynchronizationPlanningError.invalidLogicalDiff
                }
                position = beforePosition
            }
            targetPositions[moved.logicalNodeID] = position
        }
        return targetPositions
    }

    private func operationOrder(
        _ lhs: SynchronizationOperation,
        _ rhs: SynchronizationOperation
    ) -> Bool {
        if lhs.logicalNodeID != rhs.logicalNodeID {
            return lhs.logicalNodeID < rhs.logicalNodeID
        }
        return lhs.rank < rhs.rank
    }

    private func orderCreateOperations(
        _ operations: [SynchronizationOperation],
        before: LogicalStateGraph
    ) throws -> [SynchronizationOperation] {
        try CreationDependencyOrderer(
            operations: operations,
            existingNodeIDs: Set(before.nodes.map(\.logicalNodeID))
        ).ordered()
    }

    private func orderStructuralOperations(
        _ operations: [SynchronizationOperation],
        afterCreating creations: [SynchronizationOperation],
        before: LogicalStateGraph,
        deletedNodeIDs: Set<LogicalNodeID>
    ) throws -> [SynchronizationOperation] {
        try StructuralDependencyOrderer(
            operations: operations,
            creations: creations,
            before: before,
            deletedNodeIDs: deletedNodeIDs
        ).ordered()
    }

    /// Reorders only delete slots. Every non-delete cleanup operation retains
    /// the exact position assigned by the existing deterministic ordering.
    private func orderDeleteOperations(
        in operations: [SynchronizationOperation],
        before: LogicalStateGraph
    ) throws -> [SynchronizationOperation] {
        var resolver = DeletionDepthResolver(nodes: before.nodes)
        var orderedDeletes: [(operation: SynchronizationOperation, depth: Int)] = []

        for operation in operations {
            guard case .delete = operation else { continue }
            orderedDeletes.append((
                operation: operation,
                depth: try resolver.depth(for: operation.logicalNodeID)
            ))
        }
        orderedDeletes.sort { lhs, rhs in
            if lhs.depth != rhs.depth {
                return lhs.depth > rhs.depth
            }
            return lhs.operation.logicalNodeID < rhs.operation.logicalNodeID
        }

        var iterator = orderedDeletes.map(\.operation).makeIterator()
        var result: [SynchronizationOperation] = []
        result.reserveCapacity(operations.count)
        for operation in operations {
            guard case .delete = operation else {
                result.append(operation)
                continue
            }
            guard let orderedDelete = iterator.next() else {
                throw SynchronizationPlanningError.inconsistentPlan
            }
            result.append(orderedDelete)
        }
        guard iterator.next() == nil else {
            throw SynchronizationPlanningError.inconsistentPlan
        }
        return result
    }

    private func validatePlan(_ phases: [SynchronizationPhase]) throws {
        guard phases.count == 4,
              case .preparation = phases[0],
              case .structural = phases[1],
              case .content = phases[2],
              case .cleanup = phases[3] else {
            throw SynchronizationPlanningError.inconsistentPlan
        }
        let operations = phases.flatMap(\.operations)
        var keys: Set<OperationKey> = []
        var ranksByIdentity: [LogicalNodeID: Set<Int>] = [:]
        for operation in operations {
            guard keys.insert(OperationKey(operation)).inserted else {
                throw SynchronizationPlanningError.inconsistentPlan
            }
            ranksByIdentity[operation.logicalNodeID, default: []].insert(operation.rank)
        }
        for ranks in ranksByIdentity.values {
            guard !(ranks.contains(0) && ranks.count > 1),
                  !(ranks.contains(6) && ranks.count > 1),
                  !(ranks.contains(5) && ranks.contains(6)),
                  !(ranks.contains(1) && ranks.contains(2)) else {
                throw SynchronizationPlanningError.inconsistentPlan
            }
        }
    }
}

/// Merges the already validated creation and structural orders against the
/// child counts that exist at each intermediate step. A creation remains in
/// preparation only while it can execute before every structural mutation;
/// once a move is required, all following structural mutations and dependent
/// creations share the structural phase in their exact executable order.
private nonisolated struct PositionDependencyScheduler {
    private let creations: [SynchronizationOperation]
    private let structuralOperations: [SynchronizationOperation]
    private let before: LogicalStateGraph

    init(
        creations: [SynchronizationOperation],
        structuralOperations: [SynchronizationOperation],
        before: LogicalStateGraph
    ) {
        self.creations = creations
        self.structuralOperations = structuralOperations
        self.before = before
    }

    func ordered() throws -> (
        preparation: [SynchronizationOperation],
        structural: [SynchronizationOperation]
    ) {
        var state = try PositionPlanningState(before: before)
        var remainingCreations = creations
        var remainingStructural = structuralOperations
        var preparation: [SynchronizationOperation] = []
        var structural: [SynchronizationOperation] = []
        var structuralPhaseStarted = false

        while !remainingCreations.isEmpty || !remainingStructural.isEmpty {
            let pending = remainingCreations + remainingStructural
            if let creationIndex = firstReadyOperationIndex(
                in: remainingCreations,
                state: state,
                pending: pending
            ) {
                let creation = remainingCreations.remove(
                    at: creationIndex
                )
                try state.apply(creation)
                if structuralPhaseStarted {
                    structural.append(creation)
                } else {
                    preparation.append(creation)
                }
                continue
            }
            if let structuralIndex = firstReadyOperationIndex(
                in: remainingStructural,
                state: state,
                pending: pending
            ) {
                let structuralOperation = remainingStructural.remove(
                    at: structuralIndex
                )
                structuralPhaseStarted = true
                try state.apply(structuralOperation)
                structural.append(structuralOperation)
                continue
            }

            let blockedIDs = (
                remainingCreations + remainingStructural
            ).map(\.logicalNodeID)
            throw SynchronizationPlanningError
                .unresolvablePositionDependency(
                    Array(Set(blockedIDs)).sorted()
                )
        }
        return (preparation, structural)
    }

    /// The pre-existing topological orders remain the stable priority. A
    /// blocked head does not hide a later independent operation that can make
    /// its position reachable.
    private func firstReadyOperationIndex(
        in operations: [SynchronizationOperation],
        state: PositionPlanningState,
        pending: [SynchronizationOperation]
    ) -> Int? {
        operations.indices.first { index in
            let operation = operations[index]
            return state.canApply(operation)
                && !isBlockedByEarlierDestinationOperation(
                    operation,
                    pending: pending
                )
        }
    }

    /// Operations that insert into one destination establish its final prefix
    /// in increasing position order. This is a real dependency even when the
    /// current child count would make a later insertion technically possible.
    private func isBlockedByEarlierDestinationOperation(
        _ operation: SynchronizationOperation,
        pending: [SynchronizationOperation]
    ) -> Bool {
        guard let insertion = PositionInsertion(operation) else {
            return false
        }
        return pending.contains { candidate in
            guard let other = PositionInsertion(candidate),
                  other.parentID == insertion.parentID else {
                return false
            }
            if other.position != insertion.position {
                return other.position < insertion.position
            }
            return other.logicalNodeID < insertion.logicalNodeID
        }
    }
}

private nonisolated struct PositionInsertion {
    let logicalNodeID: LogicalNodeID
    let parentID: LogicalNodeID?
    let position: Int

    init?(_ operation: SynchronizationOperation) {
        switch operation {
        case .create(let create):
            logicalNodeID = create.logicalNodeID
            parentID = create.parentID
            position = create.position
        case .move(let move):
            logicalNodeID = move.logicalNodeID
            parentID = move.parentID
            position = move.position
        case .reorder, .rename, .updateURL, .archive, .delete:
            return nil
        }
    }
}

private nonisolated struct PositionPlanningState {
    private var existingNodeIDs: Set<LogicalNodeID>
    private var parentByNodeID: [LogicalNodeID: LogicalNodeID]
    private var childCountByParent: [LogicalNodeID?: Int]

    init(before: LogicalStateGraph) throws {
        existingNodeIDs = Set(before.nodes.map(\.logicalNodeID))
        parentByNodeID = Dictionary(
            uniqueKeysWithValues: before.nodes.compactMap { node in
                guard let parentID = node.parentID else { return nil }
                return (node.logicalNodeID, parentID)
            }
        )
        childCountByParent = Dictionary(
            grouping: before.nodes,
            by: \.parentID
        ).mapValues(\.count)
    }

    func canApply(_ operation: SynchronizationOperation) -> Bool {
        switch operation {
        case .create(let create):
            guard !existingNodeIDs.contains(create.logicalNodeID),
                  parentExists(create.parentID) else {
                return false
            }
            return isValidInsertion(
                create.position,
                childCount: childCount(for: create.parentID)
            )
        case .move(let move):
            guard existingNodeIDs.contains(move.logicalNodeID),
                  parentExists(move.parentID),
                  !wouldCreateCycle(
                    moving: move.logicalNodeID,
                    to: move.parentID
                  ) else {
                return false
            }
            let oldParent = parentByNodeID[move.logicalNodeID]
            let availableCount = childCount(for: move.parentID)
                - (oldParent == move.parentID ? 1 : 0)
            return isValidInsertion(
                move.position,
                childCount: availableCount
            )
        case .reorder(let reorder):
            guard existingNodeIDs.contains(reorder.logicalNodeID) else {
                return false
            }
            let parentID = parentByNodeID[reorder.logicalNodeID]
            return isValidInsertion(
                reorder.position,
                childCount: childCount(for: parentID) - 1
            )
        case .rename, .updateURL, .archive, .delete:
            return false
        }
    }

    mutating func apply(_ operation: SynchronizationOperation) throws {
        guard canApply(operation) else {
            throw SynchronizationPlanningError
                .unresolvablePositionDependency([operation.logicalNodeID])
        }
        switch operation {
        case .create(let create):
            existingNodeIDs.insert(create.logicalNodeID)
            if let parentID = create.parentID {
                parentByNodeID[create.logicalNodeID] = parentID
            }
            incrementChildren(of: create.parentID)
        case .move(let move):
            let oldParent = parentByNodeID[move.logicalNodeID]
            if oldParent != move.parentID {
                decrementChildren(of: oldParent)
                incrementChildren(of: move.parentID)
            }
            if let parentID = move.parentID {
                parentByNodeID[move.logicalNodeID] = parentID
            } else {
                parentByNodeID.removeValue(forKey: move.logicalNodeID)
            }
        case .reorder:
            break
        case .rename, .updateURL, .archive, .delete:
            throw SynchronizationPlanningError.inconsistentPlan
        }
    }

    private func parentExists(_ parentID: LogicalNodeID?) -> Bool {
        parentID.map(existingNodeIDs.contains) ?? true
    }

    private func childCount(for parentID: LogicalNodeID?) -> Int {
        childCountByParent[parentID, default: 0]
    }

    private func isValidInsertion(
        _ position: Int,
        childCount: Int
    ) -> Bool {
        position >= 0 && position <= childCount
    }

    private func wouldCreateCycle(
        moving logicalNodeID: LogicalNodeID,
        to parentID: LogicalNodeID?
    ) -> Bool {
        var ancestor = parentID
        var visited: Set<LogicalNodeID> = []
        while let ancestorID = ancestor {
            guard ancestorID != logicalNodeID,
                  visited.insert(ancestorID).inserted else {
                return true
            }
            ancestor = parentByNodeID[ancestorID]
        }
        return false
    }

    private mutating func incrementChildren(
        of parentID: LogicalNodeID?
    ) {
        childCountByParent[parentID, default: 0] += 1
    }

    private mutating func decrementChildren(
        of parentID: LogicalNodeID?
    ) {
        childCountByParent[parentID, default: 0] -= 1
    }
}

/// Deterministic topological ordering for the preparation phase. Explicit
/// edges ensure that a created parent exists before any created descendant.
private nonisolated struct CreationDependencyOrderer {
    private let operationsByID: [LogicalNodeID: SynchronizationOperation]
    private let existingNodeIDs: Set<LogicalNodeID>

    init(
        operations: [SynchronizationOperation],
        existingNodeIDs: Set<LogicalNodeID>
    ) throws {
        var indexed: [LogicalNodeID: SynchronizationOperation] = [:]
        for operation in operations {
            guard case .create = operation,
                  indexed.updateValue(
                    operation,
                    forKey: operation.logicalNodeID
                  ) == nil else {
                throw SynchronizationPlanningError.inconsistentPlan
            }
        }
        operationsByID = indexed
        self.existingNodeIDs = existingNodeIDs
    }

    func ordered() throws -> [SynchronizationOperation] {
        var dependencies = Dictionary(
            uniqueKeysWithValues: operationsByID.keys.map { ($0, Set<LogicalNodeID>()) }
        )
        var childrenByParent: [LogicalNodeID?: [CreateNodeOperation]] = [:]

        for operation in operationsByID.values {
            guard case .create(let create) = operation else {
                throw SynchronizationPlanningError.inconsistentPlan
            }
            if let parentID = create.parentID {
                if operationsByID[parentID] != nil {
                    dependencies[create.logicalNodeID, default: []].insert(parentID)
                } else if !existingNodeIDs.contains(parentID) {
                    throw SynchronizationPlanningError.missingParent(
                        logicalNodeID: create.logicalNodeID,
                        parentID: parentID
                    )
                }
            }
            childrenByParent[create.parentID, default: []].append(create)
        }

        // Siblings are inserted at their final positions. Ordering them by
        // position prevents an insertion from targeting a slot that has not
        // been created yet; LogicalNodeID resolves equal-position ties.
        for siblings in childrenByParent.values {
            let orderedSiblings = siblings.sorted {
                if $0.position != $1.position {
                    return $0.position < $1.position
                }
                return $0.logicalNodeID < $1.logicalNodeID
            }
            for pair in zip(orderedSiblings, orderedSiblings.dropFirst()) {
                dependencies[pair.1.logicalNodeID, default: []].insert(
                    pair.0.logicalNodeID
                )
            }
        }

        var result: [SynchronizationOperation] = []
        var remaining = Set(operationsByID.keys)
        while !remaining.isEmpty {
            let ready = remaining
                .filter { dependencies[$0, default: []].isDisjoint(with: remaining) }
                .sorted()
            guard let nextID = ready.first,
                  let operation = operationsByID[nextID] else {
                throw SynchronizationPlanningError
                    .unresolvableOperationDependency(remaining.sorted())
            }
            result.append(operation)
            remaining.remove(nextID)
        }
        return result
    }
}

/// Orders structural mutations against both the final dependency graph and
/// the parent graph that exists after each scheduled operation. The latter
/// prevents a valid final graph from being reached through a transient cycle.
private nonisolated struct StructuralDependencyOrderer {
    private let operationsByKey: [OperationKey: SynchronizationOperation]
    private let createdNodeIDs: Set<LogicalNodeID>
    private let createdParents: [LogicalNodeID: LogicalNodeID]
    private let initialNodeIDs: Set<LogicalNodeID>
    private let initialParents: [LogicalNodeID: LogicalNodeID]
    private let deletedNodeIDs: Set<LogicalNodeID>

    init(
        operations: [SynchronizationOperation],
        creations: [SynchronizationOperation],
        before: LogicalStateGraph,
        deletedNodeIDs: Set<LogicalNodeID>
    ) throws {
        var indexed: [OperationKey: SynchronizationOperation] = [:]
        for operation in operations {
            switch operation {
            case .move, .reorder:
                guard indexed.updateValue(
                    operation,
                    forKey: OperationKey(operation)
                ) == nil else {
                    throw SynchronizationPlanningError.inconsistentPlan
                }
            default:
                throw SynchronizationPlanningError.inconsistentPlan
            }
        }
        var createdIDs: Set<LogicalNodeID> = []
        var created: [LogicalNodeID: LogicalNodeID] = [:]
        for operation in creations {
            guard case .create(let create) = operation else {
                throw SynchronizationPlanningError.inconsistentPlan
            }
            createdIDs.insert(create.logicalNodeID)
            if let parentID = create.parentID {
                created[create.logicalNodeID] = parentID
            }
        }
        operationsByKey = indexed
        createdNodeIDs = createdIDs
        createdParents = created
        initialNodeIDs = Set(before.nodes.map(\.logicalNodeID))
        initialParents = Dictionary(uniqueKeysWithValues: before.nodes.compactMap {
            guard let parentID = $0.parentID else { return nil }
            return ($0.logicalNodeID, parentID)
        })
        self.deletedNodeIDs = deletedNodeIDs
    }

    func ordered() throws -> [SynchronizationOperation] {
        let knownNodeIDs = initialNodeIDs.union(createdNodeIDs)
        var currentParents = initialParents
        for (logicalNodeID, parentID) in createdParents {
            currentParents[logicalNodeID] = parentID
        }
        let moveOperations = operationsByKey.values.compactMap { operation -> MoveNodeOperation? in
            guard case .move(let move) = operation else { return nil }
            return move
        }
        var finalParents = currentParents
        for move in moveOperations {
            guard knownNodeIDs.contains(move.logicalNodeID) else {
                throw dependencyError([move.logicalNodeID])
            }
            if let parentID = move.parentID {
                finalParents[move.logicalNodeID] = parentID
            } else {
                finalParents.removeValue(forKey: move.logicalNodeID)
            }
        }
        try validateFinalParents(finalParents, knownNodeIDs: knownNodeIDs)

        var dependencies = Dictionary(
            uniqueKeysWithValues: operationsByKey.keys.map { ($0, Set<OperationKey>()) }
        )
        let moveKeyByID = Dictionary(
            uniqueKeysWithValues: moveOperations.map {
                ($0.logicalNodeID, OperationKey(.move($0)))
            }
        )

        // A moved destination ancestor must reach its own final parent first.
        // This also makes an old descendant that becomes the new parent detach
        // before its former ancestor is placed below it.
        for move in moveOperations {
            let moveKey = OperationKey(.move(move))
            var ancestor = move.parentID
            var visited: Set<LogicalNodeID> = []
            while let ancestorID = ancestor {
                guard visited.insert(ancestorID).inserted else {
                    throw dependencyError(visited.sorted())
                }
                if let ancestorMoveKey = moveKeyByID[ancestorID] {
                    dependencies[moveKey, default: []].insert(ancestorMoveKey)
                }
                ancestor = finalParents[ancestorID]
            }
        }

        // Insertions into one parent use final position then identity. This is
        // deterministic and keeps every requested insertion index available.
        for siblings in Dictionary(grouping: moveOperations, by: \.parentID).values {
            let orderedSiblings = siblings.sorted {
                if $0.position != $1.position {
                    return $0.position < $1.position
                }
                return $0.logicalNodeID < $1.logicalNodeID
            }
            for pair in zip(orderedSiblings, orderedSiblings.dropFirst()) {
                dependencies[OperationKey(.move(pair.1)), default: []].insert(
                    OperationKey(.move(pair.0))
                )
            }
        }

        // Reordering a container is meaningful only after all moves into or
        // out of that container have established its final child set.
        for operation in operationsByKey.values {
            guard case .reorder(let reorder) = operation,
                  let parentID = finalParents[reorder.logicalNodeID] else {
                continue
            }
            let reorderKey = OperationKey(operation)
            for move in moveOperations {
                let oldParent = currentParents[move.logicalNodeID]
                if oldParent == parentID || move.parentID == parentID {
                    dependencies[reorderKey, default: []].insert(
                        OperationKey(.move(move))
                    )
                }
            }
        }

        var result: [SynchronizationOperation] = []
        var remaining = Set(operationsByKey.keys)
        while !remaining.isEmpty {
            let ready = remaining
                .filter { dependencies[$0, default: []].isDisjoint(with: remaining) }
                .compactMap { operationsByKey[$0] }
                .filter { isStructurallySafe($0, parents: currentParents) }
                .sorted(by: stableOperationOrder)
            guard let operation = ready.first else {
                throw dependencyError(
                    remaining.map(\.logicalNodeID).sorted()
                )
            }
            result.append(operation)
            remaining.remove(OperationKey(operation))
            if case .move(let move) = operation {
                if let parentID = move.parentID {
                    currentParents[move.logicalNodeID] = parentID
                } else {
                    currentParents.removeValue(forKey: move.logicalNodeID)
                }
            }
        }
        return result
    }

    private func validateFinalParents(
        _ parents: [LogicalNodeID: LogicalNodeID],
        knownNodeIDs: Set<LogicalNodeID>
    ) throws {
        let survivingIDs = knownNodeIDs.subtracting(deletedNodeIDs)
        for logicalNodeID in survivingIDs.sorted() {
            guard let parentID = parents[logicalNodeID] else { continue }
            guard survivingIDs.contains(parentID) else {
                throw SynchronizationPlanningError.missingParent(
                    logicalNodeID: logicalNodeID,
                    parentID: parentID
                )
            }
            var ancestor: LogicalNodeID? = parentID
            var visited: Set<LogicalNodeID> = [logicalNodeID]
            while let ancestorID = ancestor {
                guard visited.insert(ancestorID).inserted else {
                    throw dependencyError(visited.sorted())
                }
                ancestor = parents[ancestorID]
            }
        }
    }

    private func isStructurallySafe(
        _ operation: SynchronizationOperation,
        parents: [LogicalNodeID: LogicalNodeID]
    ) -> Bool {
        guard case .move(let move) = operation else { return true }
        guard initialNodeIDs.contains(move.logicalNodeID)
                || createdNodeIDs.contains(move.logicalNodeID) else {
            return false
        }
        var ancestor = move.parentID
        var visited: Set<LogicalNodeID> = []
        while let ancestorID = ancestor {
            guard ancestorID != move.logicalNodeID,
                  visited.insert(ancestorID).inserted,
                  initialNodeIDs.contains(ancestorID)
                    || createdNodeIDs.contains(ancestorID) else {
                return false
            }
            ancestor = parents[ancestorID]
        }
        return true
    }

    private func stableOperationOrder(
        _ lhs: SynchronizationOperation,
        _ rhs: SynchronizationOperation
    ) -> Bool {
        if lhs.logicalNodeID != rhs.logicalNodeID {
            return lhs.logicalNodeID < rhs.logicalNodeID
        }
        return lhs.rank < rhs.rank
    }

    private func dependencyError(
        _ logicalNodeIDs: [LogicalNodeID]
    ) -> SynchronizationPlanningError {
        .unresolvableOperationDependency(Array(Set(logicalNodeIDs)).sorted())
    }
}

/// Ephemeral depth calculation owned by the Planner. No derived depth is stored
/// in domain models or persisted beyond one planning call.
nonisolated struct DeletionDepthResolver {
    private let nodesByID: [LogicalNodeID: LogicalNodeState]
    private var resolvedDepths: [LogicalNodeID: Int] = [:]

    init(nodes: [LogicalNodeState]) {
        nodesByID = Dictionary(
            nodes.map { ($0.logicalNodeID, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    mutating func depth(for logicalNodeID: LogicalNodeID) throws -> Int {
        guard nodesByID[logicalNodeID] != nil else {
            throw SynchronizationPlanningError.missingDeletedNode(logicalNodeID)
        }
        return try resolve(logicalNodeID, path: [])
    }

    private mutating func resolve(
        _ logicalNodeID: LogicalNodeID,
        path: Set<LogicalNodeID>
    ) throws -> Int {
        if let depth = resolvedDepths[logicalNodeID] {
            return depth
        }
        guard let node = nodesByID[logicalNodeID] else {
            throw SynchronizationPlanningError.missingDeletedNode(logicalNodeID)
        }
        guard !path.contains(logicalNodeID) else {
            throw SynchronizationPlanningError.parentCycle(logicalNodeID)
        }
        guard let parentID = node.parentID else {
            resolvedDepths[logicalNodeID] = 0
            return 0
        }
        guard nodesByID[parentID] != nil else {
            throw SynchronizationPlanningError.missingParent(
                logicalNodeID: logicalNodeID,
                parentID: parentID
            )
        }

        let parentDepth = try resolve(
            parentID,
            path: path.union([logicalNodeID])
        )
        let depth = parentDepth + 1
        resolvedDepths[logicalNodeID] = depth
        return depth
    }
}

private nonisolated struct DiffCounts {
    var created = 0
    var deleted = 0
    var renamed = 0
    var urlChanged = 0
    var moved = 0
    var reordered = 0
    var lifecycleChanged = 0

    init(_ changes: [LogicalChange]) {
        for change in changes {
            switch change {
            case .created: created += 1
            case .deleted: deleted += 1
            case .renamed: renamed += 1
            case .urlChanged: urlChanged += 1
            case .moved: moved += 1
            case .reordered: reordered += 1
            case .lifecycleChanged: lifecycleChanged += 1
            }
        }
    }
}

private nonisolated struct ChangeKey: Hashable {
    let logicalNodeID: LogicalNodeID
    let rank: Int

    init(_ change: LogicalChange) {
        logicalNodeID = change.logicalNodeID
        switch change {
        case .created: rank = 0
        case .deleted: rank = 1
        case .renamed: rank = 2
        case .urlChanged: rank = 3
        case .moved: rank = 4
        case .reordered: rank = 5
        case .lifecycleChanged: rank = 6
        }
    }
}

private nonisolated struct OperationKey: Hashable {
    let logicalNodeID: LogicalNodeID
    let rank: Int

    init(_ operation: SynchronizationOperation) {
        logicalNodeID = operation.logicalNodeID
        rank = operation.rank
    }
}
