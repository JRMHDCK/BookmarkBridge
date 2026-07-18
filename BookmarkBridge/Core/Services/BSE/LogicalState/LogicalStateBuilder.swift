//
//  LogicalStateBuilder.swift
//  BookmarkBridge
//

import Foundation

/// Pure merger of durable Baseline identity metadata and logical snapshot data.
nonisolated struct LogicalStateBuilder: Sendable {
    init() {}

    func build(
        request: LogicalStateBuildingRequest
    ) throws -> LogicalStateGraph {
        try validate(request.baseline)
        let snapshotOccurrences = try validatedSnapshotOccurrences(
            request.logicalSnapshots
        )
        let recordsByID = Dictionary(uniqueKeysWithValues:
            request.baseline.identityRecords.map { ($0.logicalNodeID, $0) }
        )
        let logicalNodeIDs = Set(recordsByID.keys)
            .union(snapshotOccurrences.keys)
            .sorted()

        let nodes = try logicalNodeIDs.map { logicalNodeID in
            try makeNodeState(
                logicalNodeID: logicalNodeID,
                record: recordsByID[logicalNodeID],
                snapshotOccurrences: snapshotOccurrences[logicalNodeID] ?? [:]
            )
        }
        let report = LogicalStateBuildingReport(
            baselineIdentityCount: request.baseline.identityRecords.count,
            snapshotCount: request.logicalSnapshots.count,
            snapshotNodeCount: request.logicalSnapshots.reduce(0) {
                $0 + $1.tree.nodes.count
            },
            logicalNodeCount: nodes.count,
            structurallyAvailableNodeCount: nodes.count { $0.kind != nil },
            baselineOnlyNodeCount: nodes.count {
                $0.kind == nil && $0.lifecycle != .unregistered
            },
            unregisteredNodeCount: nodes.count { $0.lifecycle == .unregistered },
            observationCount: nodes.reduce(0) { $0 + $1.observations.count }
        )
        return try LogicalStateGraph(nodes: nodes, report: report)
    }

    private func validate(_ baseline: Baseline) throws {
        guard baseline.schemaVersion == .current else {
            throw LogicalStateBuildingError.invalidBaseline
        }
        var identityIDs: Set<LogicalNodeID> = []
        for record in baseline.identityRecords {
            guard identityIDs.insert(record.logicalNodeID).inserted else {
                throw LogicalStateBuildingError.invalidBaseline
            }
            var sourceIDs: Set<BSESourceID> = []
            for observation in record.observations {
                guard sourceIDs.insert(observation.sourceID).inserted else {
                    throw LogicalStateBuildingError.invalidBaseline
                }
            }
        }
    }

    private func validatedSnapshotOccurrences(
        _ snapshots: [LogicalSnapshot]
    ) throws -> [LogicalNodeID: [BSESourceID: SnapshotOccurrence]] {
        var sources: Set<BSESourceID> = []
        var occurrences: [LogicalNodeID: [BSESourceID: SnapshotOccurrence]] = [:]

        for snapshot in snapshots.sorted(by: snapshotOrder) {
            guard sources.insert(snapshot.source).inserted else {
                let existingIDs = Set(occurrences.compactMap { logicalNodeID, bySource in
                    bySource[snapshot.source] == nil ? nil : logicalNodeID
                })
                if let duplicate = existingIDs
                    .intersection(snapshot.tree.nodes.map(\.logicalID))
                    .sorted().first {
                    throw LogicalStateBuildingError.duplicateLogicalNode(
                        logicalNodeID: duplicate,
                        sourceID: snapshot.source
                    )
                }
                throw LogicalStateBuildingError.invalidLogicalSnapshot(snapshot.source)
            }
            for node in snapshot.tree.nodes {
                let occurrence = SnapshotOccurrence(
                    capturedAt: snapshot.capturedAt,
                    node: node
                )
                guard occurrences[node.logicalID, default: [:]].updateValue(
                    occurrence,
                    forKey: snapshot.source
                ) == nil else {
                    throw LogicalStateBuildingError.duplicateLogicalNode(
                        logicalNodeID: node.logicalID,
                        sourceID: snapshot.source
                    )
                }
            }
        }
        return occurrences
    }

    private func makeNodeState(
        logicalNodeID: LogicalNodeID,
        record: IdentityRecord?,
        snapshotOccurrences: [BSESourceID: SnapshotOccurrence]
    ) throws -> LogicalNodeState {
        let structures = Set(snapshotOccurrences.values.map {
            LogicalStructure(node: $0.node)
        })
        guard structures.count <= 1 else {
            throw LogicalStateBuildingError.inconsistentGraph(logicalNodeID)
        }
        let structure = structures.first
        let baselineBySource = Dictionary(uniqueKeysWithValues:
            (record?.observations ?? []).map { ($0.sourceID, $0) }
        )
        let sourceIDs = Set(baselineBySource.keys)
            .union(snapshotOccurrences.keys)
            .sorted(by: sourceOrder)
        let observations = sourceIDs.map { sourceID in
            LogicalNodeStateObservation(
                sourceID: sourceID,
                snapshotCapturedAt: snapshotOccurrences[sourceID]?.capturedAt,
                snapshotNode: snapshotOccurrences[sourceID]?.node,
                baselineObservation: baselineBySource[sourceID]
            )
        }
        return try LogicalNodeState(
            logicalNodeID: logicalNodeID,
            kind: structure?.kind,
            title: structure?.title,
            url: structure?.url,
            parentID: structure?.parentID,
            position: structure?.position,
            lifecycle: record.map { .registered($0.state) } ?? .unregistered,
            observations: observations
        )
    }

    private func snapshotOrder(_ lhs: LogicalSnapshot, _ rhs: LogicalSnapshot) -> Bool {
        sourceOrder(lhs.source, rhs.source)
    }

    private func sourceOrder(_ lhs: BSESourceID, _ rhs: BSESourceID) -> Bool {
        lhs.rawValue.uuidString < rhs.rawValue.uuidString
    }
}

private nonisolated struct SnapshotOccurrence: Hashable, Sendable {
    let capturedAt: Date
    let node: BSENode
}

private nonisolated struct LogicalStructure: Hashable, Sendable {
    let kind: NodeKind
    let title: String
    let url: URL?
    let parentID: LogicalNodeID?
    let position: Int

    init(node: BSENode) {
        kind = node.kind
        title = node.title
        url = node.url
        parentID = node.parentID
        position = node.position
    }
}
