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
            let operation = try makeOperation(
                for: change,
                policy: request.policy
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

        preparation.sort(by: operationOrder)
        structural.sort(by: operationOrder)
        content.sort(by: operationOrder)
        cleanup.sort(by: operationOrder)
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

    private func makeOperation(
        for change: LogicalChange,
        policy: SynchronizationPolicy
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
            return .move(MoveNodeOperation(
                logicalNodeID: change.logicalNodeID,
                parentID: change.after
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

    private func operationOrder(
        _ lhs: SynchronizationOperation,
        _ rhs: SynchronizationOperation
    ) -> Bool {
        if lhs.logicalNodeID != rhs.logicalNodeID {
            return lhs.logicalNodeID < rhs.logicalNodeID
        }
        return lhs.rank < rhs.rank
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
                  !(ranks.contains(5) && ranks.contains(6)) else {
                throw SynchronizationPlanningError.inconsistentPlan
            }
        }
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
