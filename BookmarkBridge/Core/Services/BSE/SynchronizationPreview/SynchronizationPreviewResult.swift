//
//  SynchronizationPreviewResult.swift
//  BookmarkBridge
//

import Foundation

/// UI-ready summary backed by the existing logical diff and plan models.
/// Detailed rows are derived from the exact planned operations and projected
/// states instead of being independently inferred by the presentation layer.
nonisolated enum SynchronizationPreviewChangeKind: Hashable, Sendable {
    case creation
    case deletion
    case move
    case rename
    case update
}

/// Stable, browser-neutral details for one operation shown in the dry-run.
/// Values come from the exact projected states used to build the confirmed
/// plan, so the UI never has to infer bookmark names from native files.
nonisolated struct SynchronizationPreviewChangeDetail: Hashable, Sendable {
    let kind: SynchronizationPreviewChangeKind
    let logicalNodeID: LogicalNodeID
    let isFolder: Bool
    let title: String
    let url: URL?
    let previousTitle: String?
    let previousURL: URL?
    let destinationTitle: String?
}

nonisolated struct SynchronizationPreviewResult: Hashable, Sendable {
    let request: SynchronizationPreviewRequest
    let direction: ProductionSynchronizationDirection
    let logicalDiff: LogicalDiffResult
    let plan: SynchronizationPlan
    let planFingerprint: SynchronizationPlanFingerprint
    let sourceSnapshotFingerprint: SynchronizationSnapshotFingerprint
    let targetSnapshotFingerprint: SynchronizationSnapshotFingerprint
    let totalOperationCount: Int
    let creationCount: Int
    let deletionCount: Int
    let renameCount: Int
    let moveCount: Int
    let urlModificationCount: Int
    let changeDetails: [SynchronizationPreviewChangeDetail]

    init(
        request: SynchronizationPreviewRequest,
        sourceSnapshot: BSESnapshot,
        targetSnapshot: BSESnapshot,
        logicalDiff: LogicalDiffResult,
        plan: SynchronizationPlan,
        before: LogicalStateGraph? = nil,
        after: LogicalStateGraph? = nil
    ) throws {
        let operations = plan.phases.flatMap(\.operations)
        self.request = request
        direction = request.direction
        self.logicalDiff = logicalDiff
        self.plan = plan
        planFingerprint = try PlanConfirmationFingerprinting.plan(plan)
        sourceSnapshotFingerprint = try PlanConfirmationFingerprinting.snapshot(
            sourceSnapshot
        )
        targetSnapshotFingerprint = try PlanConfirmationFingerprinting.snapshot(
            targetSnapshot
        )
        totalOperationCount = operations.count
        creationCount = operations.count {
            if case .create = $0 { true } else { false }
        }
        deletionCount = operations.count {
            if case .delete = $0 { true } else { false }
        }
        renameCount = operations.count {
            if case .rename = $0 { true } else { false }
        }
        moveCount = operations.count {
            if case .move = $0 { true } else { false }
        }
        urlModificationCount = operations.count {
            if case .updateURL = $0 { true } else { false }
        }
        changeDetails = operations.map {
            Self.makeChangeDetail($0, before: before, after: after)
        }
    }

    private static func makeChangeDetail(
        _ operation: SynchronizationOperation,
        before: LogicalStateGraph?,
        after: LogicalStateGraph?
    ) -> SynchronizationPreviewChangeDetail {
        let beforeNode = before?.node(for: operation.logicalNodeID)
        let afterNode = after?.node(for: operation.logicalNodeID)
        let referenceNode = afterNode ?? beforeNode

        switch operation {
        case .create(let creation):
            return detail(
                kind: .creation,
                operation: operation,
                node: afterNode,
                fallbackTitle: creation.title,
                fallbackURL: creation.url,
                fallbackKind: creation.kind
            )
        case .delete, .archive:
            return detail(
                kind: .deletion,
                operation: operation,
                node: beforeNode ?? referenceNode
            )
        case .move(let move):
            return detail(
                kind: .move,
                operation: operation,
                node: referenceNode,
                destinationTitle: title(
                    of: move.parentID,
                    in: after
                )
            )
        case .reorder:
            return detail(
                kind: .move,
                operation: operation,
                node: referenceNode,
                destinationTitle: title(
                    of: afterNode?.parentID,
                    in: after
                )
            )
        case .rename(let rename):
            return detail(
                kind: .rename,
                operation: operation,
                node: afterNode ?? referenceNode,
                fallbackTitle: rename.title,
                previousTitle: beforeNode?.title
            )
        case .updateURL(let update):
            return detail(
                kind: .update,
                operation: operation,
                node: afterNode ?? referenceNode,
                fallbackURL: update.url,
                previousURL: beforeNode?.url
            )
        }
    }

    private static func detail(
        kind: SynchronizationPreviewChangeKind,
        operation: SynchronizationOperation,
        node: LogicalNodeState?,
        fallbackTitle: String = "",
        fallbackURL: URL? = nil,
        fallbackKind: NodeKind? = nil,
        previousTitle: String? = nil,
        previousURL: URL? = nil,
        destinationTitle: String? = nil
    ) -> SynchronizationPreviewChangeDetail {
        SynchronizationPreviewChangeDetail(
            kind: kind,
            logicalNodeID: operation.logicalNodeID,
            isFolder: (node?.kind ?? fallbackKind) == .folder,
            title: node?.title ?? fallbackTitle,
            url: node?.url ?? fallbackURL,
            previousTitle: previousTitle,
            previousURL: previousURL,
            destinationTitle: destinationTitle
        )
    }

    private static func title(
        of logicalNodeID: LogicalNodeID?,
        in graph: LogicalStateGraph?
    ) -> String? {
        guard let logicalNodeID else { return nil }
        return graph?.node(for: logicalNodeID)?.title
    }
}
