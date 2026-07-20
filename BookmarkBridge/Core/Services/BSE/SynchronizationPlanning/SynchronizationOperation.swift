//
//  SynchronizationOperation.swift
//  BookmarkBridge
//

import Foundation

nonisolated struct CreateNodeOperation: Hashable, Sendable {
    let logicalNodeID: LogicalNodeID
    let kind: NodeKind
    let title: String
    let url: URL?
    let parentID: LogicalNodeID?
    let position: Int
}

nonisolated struct DeleteNodeOperation: Hashable, Sendable {
    let logicalNodeID: LogicalNodeID
}

nonisolated struct RenameNodeOperation: Hashable, Sendable {
    let logicalNodeID: LogicalNodeID
    let title: String
}

nonisolated struct UpdateURLOperation: Hashable, Sendable {
    let logicalNodeID: LogicalNodeID
    let url: URL
}

nonisolated struct MoveNodeOperation: Hashable, Sendable {
    let logicalNodeID: LogicalNodeID
    let parentID: LogicalNodeID?
    let position: Int
}

nonisolated struct ReorderNodeOperation: Hashable, Sendable {
    let logicalNodeID: LogicalNodeID
    let position: Int
}

nonisolated struct ArchiveNodeOperation: Hashable, Sendable {
    let logicalNodeID: LogicalNodeID
    let state: IdentityRecordState
}

nonisolated enum SynchronizationOperation: Hashable, Sendable {
    case create(CreateNodeOperation)
    case delete(DeleteNodeOperation)
    case rename(RenameNodeOperation)
    case updateURL(UpdateURLOperation)
    case move(MoveNodeOperation)
    case reorder(ReorderNodeOperation)
    case archive(ArchiveNodeOperation)

    var logicalNodeID: LogicalNodeID {
        switch self {
        case .create(let operation): operation.logicalNodeID
        case .delete(let operation): operation.logicalNodeID
        case .rename(let operation): operation.logicalNodeID
        case .updateURL(let operation): operation.logicalNodeID
        case .move(let operation): operation.logicalNodeID
        case .reorder(let operation): operation.logicalNodeID
        case .archive(let operation): operation.logicalNodeID
        }
    }

    var rank: Int {
        switch self {
        case .create: 0
        case .move: 1
        case .reorder: 2
        case .rename: 3
        case .updateURL: 4
        case .archive: 5
        case .delete: 6
        }
    }
}
