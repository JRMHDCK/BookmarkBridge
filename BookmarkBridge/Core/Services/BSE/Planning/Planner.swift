//
//  Planner.swift
//  BookmarkBridge
//

/// Converts already-resolved BSE decisions into immutable execution steps.
///
/// This component never observes snapshots, recalculates diffs, resolves
/// conflicts, executes operations, or accesses an external source.
nonisolated struct Planner: Sendable {

    init() {}

    func plan(from conflictResult: ConflictResult) throws -> ExecutionPlan {
        var candidates: [Candidate] = []
        var unplanned: [(index: Int, resolution: ConflictResolution)] = []

        for (index, resolution) in conflictResult.resolutions.enumerated() {
            let selectedEntries: [DiffEntry]
            switch resolution.kind {
            case .applyLeft:
                guard !resolution.leftEntries.isEmpty else {
                    throw PlannerError.missingSelectedEntries(
                        logicalID: resolution.logicalID,
                        resolutionKind: resolution.kind
                    )
                }
                selectedEntries = resolution.leftEntries
            case .applyRight:
                guard !resolution.rightEntries.isEmpty else {
                    throw PlannerError.missingSelectedEntries(
                        logicalID: resolution.logicalID,
                        resolutionKind: resolution.kind
                    )
                }
                selectedEntries = resolution.rightEntries
            case .applyBoth:
                guard !resolution.leftEntries.isEmpty,
                      !resolution.rightEntries.isEmpty else {
                    throw PlannerError.missingSelectedEntries(
                        logicalID: resolution.logicalID,
                        resolutionKind: resolution.kind
                    )
                }
                selectedEntries = resolution.leftEntries + resolution.rightEntries
            case .noAction:
                continue
            case .conflict:
                unplanned.append((index, resolution))
                continue
            }

            for entry in selectedEntries {
                guard entry.event.logicalID == resolution.logicalID else {
                    throw PlannerError.entryIdentifierMismatch(
                        expected: resolution.logicalID,
                        actual: entry.event.logicalID
                    )
                }
                candidates.append(Candidate(
                    step: ExecutionStep(
                        kind: Self.stepKind(for: entry.event.kind),
                        logicalID: resolution.logicalID,
                        entry: entry,
                        resolution: resolution
                    ),
                    inputIndex: index
                ))
            }
        }

        let optimized = try Self.removeDuplicates(from: candidates)
        let steps = try Self.orderedSteps(from: optimized)
        let unplannedResolutions = unplanned
            .sorted(by: Self.isResolutionOrderedBefore)
            .map(\.resolution)
        return ExecutionPlan(
            steps: steps,
            unplannedResolutions: unplannedResolutions
        )
    }

    private struct Candidate {
        let step: ExecutionStep
        let inputIndex: Int
    }

    private struct OperationKey: Hashable {
        let logicalID: LogicalNodeID
        let kind: ExecutionStepKind
    }

    private static func removeDuplicates(from candidates: [Candidate]) throws -> [Candidate] {
        var eventByOperation: [OperationKey: BSEEvent] = [:]
        var seenEvents: Set<BSEEvent> = []
        var optimized: [Candidate] = []

        for candidate in candidates {
            let key = OperationKey(
                logicalID: candidate.step.logicalID,
                kind: candidate.step.kind
            )
            if let existing = eventByOperation[key], existing != candidate.step.event {
                throw PlannerError.contradictoryEvents(
                    logicalID: key.logicalID,
                    kind: key.kind
                )
            }
            eventByOperation[key] = candidate.step.event

            if seenEvents.insert(candidate.step.event).inserted {
                optimized.append(candidate)
            }
        }
        return optimized
    }

    private static func orderedSteps(from candidates: [Candidate]) throws -> [ExecutionStep] {
        var result: [ExecutionStep] = []
        for kind in [
            ExecutionStepKind.create,
            .delete,
            .move,
            .rename,
        ] {
            let category = candidates.filter { $0.step.kind == kind }
            result.append(contentsOf: try topologicallySorted(category, kind: kind).map(\.step))
        }
        return result
    }

    private static func topologicallySorted(
        _ candidates: [Candidate],
        kind: ExecutionStepKind
    ) throws -> [Candidate] {
        let byID = Dictionary(uniqueKeysWithValues: candidates.map { ($0.step.logicalID, $0) })
        var prerequisites = Dictionary(
            uniqueKeysWithValues: byID.keys.map { ($0, Set<LogicalNodeID>()) }
        )

        for candidate in candidates {
            switch kind {
            case .create:
                if let parentID = candidate.step.event.after?.parentID, byID[parentID] != nil {
                    prerequisites[candidate.step.logicalID, default: []].insert(parentID)
                }
            case .delete:
                if let parentID = candidate.step.event.before?.parentID, byID[parentID] != nil {
                    prerequisites[parentID, default: []].insert(candidate.step.logicalID)
                }
            case .move:
                if let parentID = candidate.step.event.after?.parentID, byID[parentID] != nil {
                    prerequisites[candidate.step.logicalID, default: []].insert(parentID)
                }
            case .rename:
                break
            }
        }

        var emitted: Set<LogicalNodeID> = []
        var ordered: [Candidate] = []
        while ordered.count < candidates.count {
            let available = candidates
                .filter { candidate in
                    !emitted.contains(candidate.step.logicalID)
                        && prerequisites[candidate.step.logicalID, default: []].isSubset(of: emitted)
                }
                .sorted { isCandidateOrderedBefore($0, $1, kind: kind) }

            guard let next = available.first else {
                let remaining = byID.keys.filter { !emitted.contains($0) }.sorted()
                throw PlannerError.cyclicDependencies(kind: kind, logicalIDs: remaining)
            }
            emitted.insert(next.step.logicalID)
            ordered.append(next)
        }
        return ordered
    }

    private static func isCandidateOrderedBefore(
        _ lhs: Candidate,
        _ rhs: Candidate,
        kind: ExecutionStepKind
    ) -> Bool {
        let lhsKindOrder = nodeKindOrder(nodeKind(of: lhs.step.event), for: kind)
        let rhsKindOrder = nodeKindOrder(nodeKind(of: rhs.step.event), for: kind)
        if lhsKindOrder != rhsKindOrder { return lhsKindOrder < rhsKindOrder }
        if lhs.step.logicalID != rhs.step.logicalID {
            return lhs.step.logicalID < rhs.step.logicalID
        }
        return lhs.inputIndex < rhs.inputIndex
    }

    private static func isResolutionOrderedBefore(
        _ lhs: (index: Int, resolution: ConflictResolution),
        _ rhs: (index: Int, resolution: ConflictResolution)
    ) -> Bool {
        if lhs.resolution.logicalID != rhs.resolution.logicalID {
            return lhs.resolution.logicalID < rhs.resolution.logicalID
        }
        return lhs.index < rhs.index
    }

    private static func nodeKind(of event: BSEEvent) -> NodeKind {
        if let after = event.after { return after.kind }
        return event.before?.kind ?? .bookmark
    }

    private static func nodeKindOrder(_ nodeKind: NodeKind, for kind: ExecutionStepKind) -> Int {
        switch (kind, nodeKind) {
        case (.delete, .bookmark): 0
        case (.delete, .folder): 1
        case (_, .folder): 0
        case (_, .bookmark): 1
        }
    }

    private static func stepKind(for eventKind: BSEEventKind) -> ExecutionStepKind {
        switch eventKind {
        case .createNode: .create
        case .deleteNode: .delete
        case .moveNode: .move
        case .renameNode: .rename
        }
    }
}
