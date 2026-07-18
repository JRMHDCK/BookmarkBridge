//
//  LogicalDiffEngine.swift
//  BookmarkBridge
//

/// Pure comparison of two immutable logical state graphs.
nonisolated struct LogicalDiffEngine: Sendable {
    init() {}

    func diff(
        request: LogicalDiffRequest
    ) throws -> LogicalDiffResult {
        let before = try validatedIndex(request.before, graph: .before)
        let after = try validatedIndex(request.after, graph: .after)
        let allIDs = Set(before.keys).union(after.keys).sorted()
        var changes: [LogicalChange] = []
        var unchangedNodeCount = 0

        for logicalNodeID in allIDs {
            switch (before[logicalNodeID], after[logicalNodeID]) {
            case (nil, let afterNode?):
                changes.append(.created(CreatedChange(after: afterNode)))
            case (let beforeNode?, nil):
                changes.append(.deleted(DeletedChange(before: beforeNode)))
            case (let beforeNode?, let afterNode?):
                let nodeChanges = try makeChanges(
                    logicalNodeID: logicalNodeID,
                    before: beforeNode,
                    after: afterNode
                )
                changes.append(contentsOf: nodeChanges)
                if nodeChanges.isEmpty {
                    unchangedNodeCount += 1
                }
            case (nil, nil):
                throw LogicalDiffError.inconsistentState(logicalNodeID)
            }
        }

        let report = LogicalDiffReport(
            beforeNodeCount: before.count,
            afterNodeCount: after.count,
            unchangedNodeCount: unchangedNodeCount,
            createdCount: changes.count(of: .created),
            deletedCount: changes.count(of: .deleted),
            renamedCount: changes.count(of: .renamed),
            urlChangedCount: changes.count(of: .urlChanged),
            movedCount: changes.count(of: .moved),
            reorderedCount: changes.count(of: .reordered),
            lifecycleChangedCount: changes.count(of: .lifecycleChanged)
        )
        return LogicalDiffResult(changes: changes, report: report)
    }

    private func validatedIndex(
        _ graph: LogicalStateGraph,
        graph graphSide: LogicalDiffGraph
    ) throws -> [LogicalNodeID: LogicalNodeState] {
        var index: [LogicalNodeID: LogicalNodeState] = [:]
        for node in graph.nodes {
            guard index.updateValue(node, forKey: node.logicalNodeID) == nil else {
                throw LogicalDiffError.duplicateLogicalNode(
                    logicalNodeID: node.logicalNodeID,
                    graph: graphSide
                )
            }
        }
        return index
    }

    private func makeChanges(
        logicalNodeID: LogicalNodeID,
        before: LogicalNodeState,
        after: LogicalNodeState
    ) throws -> [LogicalChange] {
        guard before.kind == after.kind else {
            throw LogicalDiffError.inconsistentState(logicalNodeID)
        }
        var changes: [LogicalChange] = []
        if before.title != after.title {
            changes.append(.renamed(RenamedChange(
                logicalNodeID: logicalNodeID,
                before: before.title,
                after: after.title
            )))
        }
        if before.url != after.url {
            changes.append(.urlChanged(URLChangedChange(
                logicalNodeID: logicalNodeID,
                before: before.url,
                after: after.url
            )))
        }
        if before.parentID != after.parentID {
            changes.append(.moved(MovedChange(
                logicalNodeID: logicalNodeID,
                before: before.parentID,
                after: after.parentID
            )))
        }
        if before.position != after.position {
            changes.append(.reordered(ReorderedChange(
                logicalNodeID: logicalNodeID,
                before: before.position,
                after: after.position
            )))
        }
        if before.lifecycle != after.lifecycle {
            changes.append(.lifecycleChanged(LifecycleChangedChange(
                logicalNodeID: logicalNodeID,
                before: before.lifecycle,
                after: after.lifecycle
            )))
        }
        return changes
    }
}

private nonisolated extension Array where Element == LogicalChange {
    func count(of kind: LogicalChange.Kind) -> Int {
        count { $0.kind == kind }
    }
}
