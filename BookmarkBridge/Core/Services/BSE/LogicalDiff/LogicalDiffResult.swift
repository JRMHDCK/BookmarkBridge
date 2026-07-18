//
//  LogicalDiffResult.swift
//  BookmarkBridge
//

nonisolated enum LogicalIdentityChange: Hashable, Codable, Sendable {
    case created(logicalNodeID: LogicalNodeID)
    case updated(logicalNodeID: LogicalNodeID)
    case archived(logicalNodeID: LogicalNodeID)
    case reactivated(
        logicalNodeID: LogicalNodeID,
        previousState: IdentityRecordState
    )

    var logicalNodeID: LogicalNodeID {
        switch self {
        case .created(let logicalNodeID),
             .updated(let logicalNodeID),
             .archived(let logicalNodeID),
             .reactivated(let logicalNodeID, _):
            logicalNodeID
        }
    }
}

nonisolated enum LogicalObservationChange: Hashable, Codable, Sendable {
    case added(logicalNodeID: LogicalNodeID, sourceID: BSESourceID)
    case removed(logicalNodeID: LogicalNodeID, sourceID: BSESourceID)
    case restored(logicalNodeID: LogicalNodeID, sourceID: BSESourceID)

    var logicalNodeID: LogicalNodeID {
        switch self {
        case .added(let logicalNodeID, _),
             .removed(let logicalNodeID, _),
             .restored(let logicalNodeID, _):
            logicalNodeID
        }
    }

    var sourceID: BSESourceID {
        switch self {
        case .added(_, let sourceID),
             .removed(_, let sourceID),
             .restored(_, let sourceID):
            sourceID
        }
    }
}

nonisolated struct LogicalDiffResult: Hashable, Codable, Sendable {
    let identityChanges: [LogicalIdentityChange]
    let observationChanges: [LogicalObservationChange]
    let unchangedIdentityIDs: [LogicalNodeID]
    let report: LogicalDiffReport
}
