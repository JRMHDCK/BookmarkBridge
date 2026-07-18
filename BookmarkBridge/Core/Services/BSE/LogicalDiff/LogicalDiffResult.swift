//
//  LogicalDiffResult.swift
//  BookmarkBridge
//

import Foundation

nonisolated struct CreatedChange: Hashable, Codable, Sendable {
    let after: LogicalNodeState

    var logicalNodeID: LogicalNodeID { after.logicalNodeID }
}

nonisolated struct DeletedChange: Hashable, Codable, Sendable {
    let before: LogicalNodeState

    var logicalNodeID: LogicalNodeID { before.logicalNodeID }
}

nonisolated struct RenamedChange: Hashable, Codable, Sendable {
    let logicalNodeID: LogicalNodeID
    let before: String?
    let after: String?
}

nonisolated struct URLChangedChange: Hashable, Codable, Sendable {
    let logicalNodeID: LogicalNodeID
    let before: URL?
    let after: URL?
}

nonisolated struct MovedChange: Hashable, Codable, Sendable {
    let logicalNodeID: LogicalNodeID
    let before: LogicalNodeID?
    let after: LogicalNodeID?
}

nonisolated struct ReorderedChange: Hashable, Codable, Sendable {
    let logicalNodeID: LogicalNodeID
    let before: Int?
    let after: Int?
}

nonisolated struct LifecycleChangedChange: Hashable, Codable, Sendable {
    let logicalNodeID: LogicalNodeID
    let before: LogicalNodeLifecycle
    let after: LogicalNodeLifecycle
}

nonisolated enum LogicalChange: Hashable, Codable, Sendable {
    case created(CreatedChange)
    case deleted(DeletedChange)
    case renamed(RenamedChange)
    case urlChanged(URLChangedChange)
    case moved(MovedChange)
    case reordered(ReorderedChange)
    case lifecycleChanged(LifecycleChangedChange)

    var logicalNodeID: LogicalNodeID {
        switch self {
        case .created(let change): change.logicalNodeID
        case .deleted(let change): change.logicalNodeID
        case .renamed(let change): change.logicalNodeID
        case .urlChanged(let change): change.logicalNodeID
        case .moved(let change): change.logicalNodeID
        case .reordered(let change): change.logicalNodeID
        case .lifecycleChanged(let change): change.logicalNodeID
        }
    }

    var kind: Kind {
        switch self {
        case .created: .created
        case .deleted: .deleted
        case .renamed: .renamed
        case .urlChanged: .urlChanged
        case .moved: .moved
        case .reordered: .reordered
        case .lifecycleChanged: .lifecycleChanged
        }
    }

    enum Kind {
        case created
        case deleted
        case renamed
        case urlChanged
        case moved
        case reordered
        case lifecycleChanged
    }
}

nonisolated struct LogicalDiffResult: Hashable, Codable, Sendable {
    let changes: [LogicalChange]
    let report: LogicalDiffReport
}
