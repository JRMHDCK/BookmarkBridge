//
//  ConflictResolver.swift
//  BookmarkBridge
//

/// Resolves two already-computed baseline diffs without inspecting snapshots A
/// or B, recalculating differences, mutating trees, or producing a plan.
nonisolated struct ConflictResolver: Sendable {

    init() {}

    func resolve(
        baseline: BSESnapshot,
        left: DiffResult,
        right: DiffResult
    ) throws -> ConflictResult {
        let baselineIDs = Set(baseline.tree.nodes.map(\.logicalID))
        let leftByID = try Self.group(
            left.entries,
            side: .left,
            baselineIDs: baselineIDs
        )
        let rightByID = try Self.group(
            right.entries,
            side: .right,
            baselineIDs: baselineIDs
        )
        let logicalIDs = Set(leftByID.keys).union(rightByID.keys).sorted()

        let resolutions = logicalIDs.map { logicalID in
            Self.resolve(
                logicalID: logicalID,
                leftEntries: leftByID[logicalID] ?? [],
                rightEntries: rightByID[logicalID] ?? []
            )
        }
        return ConflictResult(resolutions: resolutions)
    }

    private static func resolve(
        logicalID: LogicalNodeID,
        leftEntries: [DiffEntry],
        rightEntries: [DiffEntry]
    ) -> ConflictResolution {
        let decision: (kind: ConflictResolutionKind, reason: ConflictReason)

        if leftEntries.isEmpty {
            decision = (.applyRight, .changedOnlyInRight)
        } else if rightEntries.isEmpty {
            decision = (.applyLeft, .changedOnlyInLeft)
        } else if leftEntries.map(\.event) == rightEntries.map(\.event) {
            decision = (.noAction, .identicalChanges)
        } else if isURLChange(leftEntries) || isURLChange(rightEntries) {
            decision = (.conflict, .urlConflict)
        } else if isDeletion(leftEntries) || isDeletion(rightEntries) {
            decision = (.conflict, .deleteVsModify)
        } else if areCompatibleRenameAndMove(leftEntries, rightEntries) {
            decision = (.applyBoth, .compatibleRenameAndMove)
        } else if contains(.renameNode, in: leftEntries),
                  contains(.renameNode, in: rightEntries) {
            decision = (.conflict, .concurrentRename)
        } else if contains(.moveNode, in: leftEntries),
                  contains(.moveNode, in: rightEntries) {
            decision = (.conflict, .concurrentMove)
        } else {
            decision = (.conflict, .incompatibleChanges)
        }

        return ConflictResolution(
            logicalID: logicalID,
            kind: decision.kind,
            reason: decision.reason,
            leftEntries: leftEntries,
            rightEntries: rightEntries
        )
    }

    private static func group(
        _ entries: [DiffEntry],
        side: ConflictResolverSide,
        baselineIDs: Set<LogicalNodeID>
    ) throws -> [LogicalNodeID: [DiffEntry]] {
        let grouped = Dictionary(grouping: entries, by: { $0.event.logicalID })
        var result: [LogicalNodeID: [DiffEntry]] = [:]

        for logicalID in grouped.keys.sorted() {
            let ordered = (grouped[logicalID] ?? []).sorted(by: isOrderedBefore)
            var eventKinds: Set<BSEEventKind> = []
            for entry in ordered {
                guard eventKinds.insert(entry.event.kind).inserted else {
                    throw ConflictResolverError.duplicateEvent(
                        logicalID: logicalID,
                        kind: entry.event.kind,
                        side: side
                    )
                }
            }

            guard isValidSequence(
                ordered,
                baselineContainsNode: baselineIDs.contains(logicalID)
            ) else {
                throw ConflictResolverError.invalidEventSequence(
                    logicalID: logicalID,
                    side: side
                )
            }
            result[logicalID] = ordered
        }
        return result
    }

    private static func isValidSequence(
        _ entries: [DiffEntry],
        baselineContainsNode: Bool
    ) -> Bool {
        guard !entries.isEmpty else { return false }

        if !baselineContainsNode {
            return entries.count == 1
                && entries[0].event.kind == .createNode
                && entries[0].reason == .createdInAfterSnapshot
        }

        let kinds = Set(entries.map(\.event.kind))
        if kinds == [.createNode, .deleteNode] {
            return entries.allSatisfy { $0.reason == .bookmarkURLChanged }
        }
        if kinds == [.deleteNode] {
            return entries[0].reason == .missingFromAfterSnapshot
        }
        if kinds == [.moveNode] {
            return isMoveReason(entries[0].reason)
        }
        if kinds == [.renameNode] {
            return entries[0].reason == .titleChanged
        }
        if kinds == [.moveNode, .renameNode] {
            return entries.contains { $0.event.kind == .moveNode && isMoveReason($0.reason) }
                && entries.contains { $0.event.kind == .renameNode && $0.reason == .titleChanged }
        }
        return false
    }

    private static func isMoveReason(_ reason: DiffReason) -> Bool {
        switch reason {
        case .parentChanged, .positionChanged, .parentAndPositionChanged:
            true
        case .createdInAfterSnapshot, .missingFromAfterSnapshot, .titleChanged,
             .bookmarkURLChanged:
            false
        }
    }

    private static func isURLChange(_ entries: [DiffEntry]) -> Bool {
        contains(.createNode, in: entries) && contains(.deleteNode, in: entries)
    }

    private static func isDeletion(_ entries: [DiffEntry]) -> Bool {
        entries.count == 1 && entries[0].event.kind == .deleteNode
    }

    private static func areCompatibleRenameAndMove(
        _ leftEntries: [DiffEntry],
        _ rightEntries: [DiffEntry]
    ) -> Bool {
        let leftKind = leftEntries.count == 1 ? leftEntries[0].event.kind : nil
        let rightKind = rightEntries.count == 1 ? rightEntries[0].event.kind : nil
        return (leftKind == .renameNode && rightKind == .moveNode)
            || (leftKind == .moveNode && rightKind == .renameNode)
    }

    private static func contains(_ kind: BSEEventKind, in entries: [DiffEntry]) -> Bool {
        entries.contains { $0.event.kind == kind }
    }

    private static func isOrderedBefore(_ lhs: DiffEntry, _ rhs: DiffEntry) -> Bool {
        eventOrder(lhs.event.kind) < eventOrder(rhs.event.kind)
    }

    private static func eventOrder(_ kind: BSEEventKind) -> Int {
        switch kind {
        case .createNode: 0
        case .deleteNode: 1
        case .moveNode: 2
        case .renameNode: 3
        }
    }
}
