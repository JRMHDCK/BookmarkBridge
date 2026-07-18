//
//  LogicalNodeState.swift
//  BookmarkBridge
//

import Foundation

nonisolated enum LogicalNodeLifecycle: Hashable, Codable, Sendable {
    case registered(IdentityRecordState)
    case unregistered
}

/// Exact source-local inputs retained without interpretation.
nonisolated struct LogicalNodeStateObservation: Hashable, Codable, Sendable {
    let sourceID: BSESourceID
    let snapshotCapturedAt: Date?
    let snapshotNode: BSENode?
    let baselineObservation: BaselineObservation?
}

/// One durable identity in the merged logical graph. Structural fields are nil
/// only when the identity exists solely in Baseline, which stores no node data.
nonisolated struct LogicalNodeState: Hashable, Codable, Sendable {
    let logicalNodeID: LogicalNodeID
    let kind: NodeKind?
    let title: String?
    let url: URL?
    let parentID: LogicalNodeID?
    let position: Int?
    let lifecycle: LogicalNodeLifecycle
    let observations: [LogicalNodeStateObservation]

    init(
        logicalNodeID: LogicalNodeID,
        kind: NodeKind?,
        title: String?,
        url: URL?,
        parentID: LogicalNodeID?,
        position: Int?,
        lifecycle: LogicalNodeLifecycle,
        observations: [LogicalNodeStateObservation]
    ) throws {
        try Self.validateStructure(
            logicalNodeID: logicalNodeID,
            kind: kind,
            title: title,
            url: url,
            parentID: parentID,
            position: position
        )
        var sourceIDs: Set<BSESourceID> = []
        for observation in observations {
            guard sourceIDs.insert(observation.sourceID).inserted,
                  observation.snapshotNode?.logicalID == logicalNodeID
                    || observation.snapshotNode == nil,
                  observation.baselineObservation?.sourceID == observation.sourceID
                    || observation.baselineObservation == nil else {
                throw LogicalStateBuildingError.inconsistentGraph(logicalNodeID)
            }
        }
        self.logicalNodeID = logicalNodeID
        self.kind = kind
        self.title = title
        self.url = url
        self.parentID = parentID
        self.position = position
        self.lifecycle = lifecycle
        self.observations = observations.sorted {
            $0.sourceID.rawValue.uuidString < $1.sourceID.rawValue.uuidString
        }
    }

    init(from decoder: any Decoder) throws {
        let values = try Values(from: decoder)
        do {
            try self.init(
                logicalNodeID: values.logicalNodeID,
                kind: values.kind,
                title: values.title,
                url: values.url,
                parentID: values.parentID,
                position: values.position,
                lifecycle: values.lifecycle,
                observations: values.observations
            )
        } catch {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Invalid logical node state")
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        try Values(
            logicalNodeID: logicalNodeID,
            kind: kind,
            title: title,
            url: url,
            parentID: parentID,
            position: position,
            lifecycle: lifecycle,
            observations: observations
        ).encode(to: encoder)
    }

    private static func validateStructure(
        logicalNodeID: LogicalNodeID,
        kind: NodeKind?,
        title: String?,
        url: URL?,
        parentID: LogicalNodeID?,
        position: Int?
    ) throws {
        guard let kind else {
            guard title == nil, url == nil, parentID == nil, position == nil else {
                throw LogicalStateBuildingError.inconsistentGraph(logicalNodeID)
            }
            return
        }
        guard title != nil, let position, position >= 0 else {
            throw LogicalStateBuildingError.inconsistentGraph(logicalNodeID)
        }
        switch kind {
        case .folder where url != nil,
             .bookmark where url == nil:
            throw LogicalStateBuildingError.inconsistentGraph(logicalNodeID)
        default:
            break
        }
    }

    private struct Values: Codable {
        let logicalNodeID: LogicalNodeID
        let kind: NodeKind?
        let title: String?
        let url: URL?
        let parentID: LogicalNodeID?
        let position: Int?
        let lifecycle: LogicalNodeLifecycle
        let observations: [LogicalNodeStateObservation]
    }
}
