//
//  DiffEngine.swift
//  BookmarkBridge
//

import Foundation

/// Pure, deterministic description of changes between two reconciled BSE
/// snapshots. Identity comes exclusively from `LogicalNodeID`.
nonisolated struct DiffEngine: Sendable {

    init() {}

    /// Describes the atomic differences observed from `before` to `after`.
    ///
    /// No tree is mutated and no conflict, planning, or transaction decision is
    /// made. The returned entries are ordered create, delete, move, rename;
    /// folders precede bookmarks in each category, then ids are ascending.
    func diff(from before: BSESnapshot, to after: BSESnapshot) throws -> DiffResult {
        let beforeByID = Dictionary(uniqueKeysWithValues: before.tree.nodes.map { ($0.logicalID, $0) })
        let afterByID = Dictionary(uniqueKeysWithValues: after.tree.nodes.map { ($0.logicalID, $0) })
        let logicalIDs = Set(beforeByID.keys).union(afterByID.keys).sorted()

        var pending: [(event: BSEEvent, reason: DiffReason, nodeKind: NodeKind)] = []

        for logicalID in logicalIDs {
            switch (beforeByID[logicalID], afterByID[logicalID]) {
            case (nil, let created?):
                pending.append((
                    event: try BSEEvent(
                        kind: .createNode,
                        logicalID: logicalID,
                        before: nil,
                        after: created
                    ),
                    reason: .createdInAfterSnapshot,
                    nodeKind: created.kind
                ))

            case (let deleted?, nil):
                pending.append((
                    event: try BSEEvent(
                        kind: .deleteNode,
                        logicalID: logicalID,
                        before: deleted,
                        after: nil
                    ),
                    reason: .missingFromAfterSnapshot,
                    nodeKind: deleted.kind
                ))

            case (let oldNode?, let newNode?):
                try describeChanges(
                    from: oldNode,
                    to: newNode,
                    into: &pending
                )

            case (nil, nil):
                break
            }
        }

        let entries = pending
            .sorted(by: Self.isOrderedBefore)
            .map { DiffEntry(event: $0.event, reason: $0.reason) }
        return DiffResult(entries: entries)
    }

    private func describeChanges(
        from oldNode: BSENode,
        to newNode: BSENode,
        into pending: inout [(event: BSEEvent, reason: DiffReason, nodeKind: NodeKind)]
    ) throws {
        guard oldNode.kind == newNode.kind else {
            throw DiffEngineError.nodeKindChanged(
                logicalID: oldNode.logicalID,
                before: oldNode.kind,
                after: newNode.kind
            )
        }

        if oldNode.kind == .bookmark,
           oldNode.url?.absoluteString != newNode.url?.absoluteString {
            pending.append((
                event: try BSEEvent(
                    kind: .deleteNode,
                    logicalID: oldNode.logicalID,
                    before: oldNode,
                    after: nil
                ),
                reason: .bookmarkURLChanged,
                nodeKind: oldNode.kind
            ))
            pending.append((
                event: try BSEEvent(
                    kind: .createNode,
                    logicalID: newNode.logicalID,
                    before: nil,
                    after: newNode
                ),
                reason: .bookmarkURLChanged,
                nodeKind: newNode.kind
            ))
            return
        }

        let parentChanged = oldNode.parentID != newNode.parentID
        let positionChanged = oldNode.position != newNode.position
        let titleChanged = oldNode.title != newNode.title

        let stateAfterMove: BSENode
        if parentChanged || positionChanged {
            stateAfterMove = try BSENode(
                logicalID: oldNode.logicalID,
                kind: oldNode.kind,
                title: oldNode.title,
                parentID: newNode.parentID,
                position: newNode.position,
                url: oldNode.url
            )
            pending.append((
                event: try BSEEvent(
                    kind: .moveNode,
                    logicalID: oldNode.logicalID,
                    before: oldNode,
                    after: stateAfterMove
                ),
                reason: Self.moveReason(
                    parentChanged: parentChanged,
                    positionChanged: positionChanged
                ),
                nodeKind: oldNode.kind
            ))
        } else {
            stateAfterMove = oldNode
        }

        if titleChanged {
            pending.append((
                event: try BSEEvent(
                    kind: .renameNode,
                    logicalID: oldNode.logicalID,
                    before: stateAfterMove,
                    after: newNode
                ),
                reason: .titleChanged,
                nodeKind: oldNode.kind
            ))
        }
    }

    private static func moveReason(parentChanged: Bool, positionChanged: Bool) -> DiffReason {
        if parentChanged {
            return positionChanged ? .parentAndPositionChanged : .parentChanged
        }
        return .positionChanged
    }

    private static func isOrderedBefore(
        _ lhs: (event: BSEEvent, reason: DiffReason, nodeKind: NodeKind),
        _ rhs: (event: BSEEvent, reason: DiffReason, nodeKind: NodeKind)
    ) -> Bool {
        let lhsEventOrder = eventOrder(lhs.event.kind)
        let rhsEventOrder = eventOrder(rhs.event.kind)
        if lhsEventOrder != rhsEventOrder { return lhsEventOrder < rhsEventOrder }

        let lhsKindOrder = nodeKindOrder(lhs.nodeKind)
        let rhsKindOrder = nodeKindOrder(rhs.nodeKind)
        if lhsKindOrder != rhsKindOrder { return lhsKindOrder < rhsKindOrder }

        return lhs.event.logicalID < rhs.event.logicalID
    }

    private static func eventOrder(_ kind: BSEEventKind) -> Int {
        switch kind {
        case .createNode: 0
        case .deleteNode: 1
        case .moveNode: 2
        case .renameNode: 3
        }
    }

    private static func nodeKindOrder(_ kind: NodeKind) -> Int {
        switch kind {
        case .folder: 0
        case .bookmark: 1
        }
    }
}
