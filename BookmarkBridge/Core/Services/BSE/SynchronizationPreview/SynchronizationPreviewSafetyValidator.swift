//
//  SynchronizationPreviewSafetyValidator.swift
//  BookmarkBridge
//

/// Rejects a plan whose apparent moves are overwhelmingly caused by different
/// logical parent IDs for the same normalized folder paths.
nonisolated struct SynchronizationPreviewSafetyValidator: Sendable {
    private static let minimumMassMoveCount = 100
    private static let minimumMassMoveShareNumerator = 1
    private static let minimumMassMoveShareDenominator = 2
    private static let minimumEquivalentPathNumerator = 9
    private static let minimumEquivalentPathDenominator = 10

    func validate(
        before: LogicalStateGraph,
        after: LogicalStateGraph,
        plan: SynchronizationPlan
    ) throws {
        let movedIDs: Set<LogicalNodeID> = Set(
            plan.operations.compactMap { operation -> LogicalNodeID? in
                guard case .move(let move) = operation else {
                    return nil
                }
                return move.logicalNodeID
            }
        )
        guard movedIDs.count >= Self.minimumMassMoveCount else {
            return
        }

        let sharedNodeCount = Set(before.nodes.map(\.logicalNodeID))
            .intersection(after.nodes.map(\.logicalNodeID))
            .count
        guard movedIDs.count * Self.minimumMassMoveShareDenominator
                >= sharedNodeCount * Self.minimumMassMoveShareNumerator else {
            return
        }

        let beforeIndex = Dictionary(
            uniqueKeysWithValues: before.nodes.map {
                ($0.logicalNodeID, $0)
            }
        )
        let afterIndex = Dictionary(
            uniqueKeysWithValues: after.nodes.map {
                ($0.logicalNodeID, $0)
            }
        )
        let equivalentPathMoveCount = movedIDs.count { logicalNodeID in
            guard let beforeNode = beforeIndex[logicalNodeID],
                  let afterNode = afterIndex[logicalNodeID],
                  beforeNode.parentID != afterNode.parentID,
                  let beforePath = folderPath(
                    to: beforeNode.parentID,
                    index: beforeIndex
                  ),
                  let afterPath = folderPath(
                    to: afterNode.parentID,
                    index: afterIndex
                  ) else {
                return false
            }
            return beforePath == afterPath
        }
        guard equivalentPathMoveCount
                * Self.minimumEquivalentPathDenominator
                >= movedIDs.count * Self.minimumEquivalentPathNumerator else {
            return
        }

        throw SynchronizationPreviewError.suspiciousStructuralChurn(
            movedCount: movedIDs.count,
            equivalentPathMoveCount: equivalentPathMoveCount
        )
    }

    private func folderPath(
        to parentID: LogicalNodeID?,
        index: [LogicalNodeID: LogicalNodeState]
    ) -> FolderPath? {
        guard var currentID = parentID else {
            return nil
        }
        var titles: [String] = []
        var visited: Set<LogicalNodeID> = []

        while visited.insert(currentID).inserted {
            guard let node = index[currentID],
                  node.kind == .folder,
                  let title = node.title else {
                return nil
            }
            if let rootRole = node.permanentRootRole {
                return FolderPath(
                    rootRole: rootRole,
                    titles: Array(titles.reversed())
                )
            }
            titles.append(title)
            guard let nextID = node.parentID else {
                return nil
            }
            currentID = nextID
        }
        return nil
    }
}

nonisolated private struct FolderPath: Hashable, Sendable {
    let rootRole: PermanentRootRole
    let titles: [String]
}
