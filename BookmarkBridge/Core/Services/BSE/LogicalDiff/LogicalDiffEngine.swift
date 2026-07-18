//
//  LogicalDiffEngine.swift
//  BookmarkBridge
//

import Foundation

/// Pure comparison of the durable identity registry with logical source views.
/// It observes presence only and never interprets node content or artifacts.
nonisolated struct LogicalDiffEngine: Sendable {
    init() {}

    func diff(
        request: LogicalDiffRequest
    ) throws -> LogicalDiffResult {
        try validate(request.baseline)
        let snapshotState = try validatedSnapshotState(request.logicalSnapshots)
        let baselineIDs = Set(request.baseline.identityRecords.map(\.logicalNodeID))
        let observedIDs = Set(snapshotState.kindsByIdentity.keys)

        var identityChanges: [LogicalIdentityChange] = []
        var observationChanges: [LogicalObservationChange] = []
        var unchangedIdentityIDs: [LogicalNodeID] = []

        for logicalNodeID in observedIDs.subtracting(baselineIDs).sorted() {
            identityChanges.append(.created(logicalNodeID: logicalNodeID))
            for sourceID in snapshotState.sourcesContaining(logicalNodeID) {
                observationChanges.append(.added(
                    logicalNodeID: logicalNodeID,
                    sourceID: sourceID
                ))
            }
        }

        for record in request.baseline.identityRecords {
            let changes = try makeObservationChanges(
                for: record,
                requestedSourceIDs: snapshotState.requestedSourceIDs,
                observedBySource: snapshotState.observedBySource
            )
            observationChanges.append(contentsOf: changes)

            let observedSources = snapshotState.sourcesContaining(record.logicalNodeID)
            if record.state != .active, !observedSources.isEmpty {
                identityChanges.append(.reactivated(
                    logicalNodeID: record.logicalNodeID,
                    previousState: record.state
                ))
            } else if shouldArchive(
                record,
                requestedSourceIDs: Set(snapshotState.requestedSourceIDs),
                observedSources: observedSources
            ) {
                identityChanges.append(.archived(
                    logicalNodeID: record.logicalNodeID
                ))
            } else if !changes.isEmpty {
                identityChanges.append(.updated(
                    logicalNodeID: record.logicalNodeID
                ))
            } else {
                unchangedIdentityIDs.append(record.logicalNodeID)
            }
        }

        identityChanges.sort(by: identityChangeOrder)
        observationChanges.sort(by: observationChangeOrder)
        unchangedIdentityIDs.sort()
        let report = makeReport(
            baseline: request.baseline,
            snapshotState: snapshotState,
            identityChanges: identityChanges,
            observationChanges: observationChanges,
            unchangedIdentityIDs: unchangedIdentityIDs
        )
        return LogicalDiffResult(
            identityChanges: identityChanges,
            observationChanges: observationChanges,
            unchangedIdentityIDs: unchangedIdentityIDs,
            report: report
        )
    }

    private func validate(_ baseline: Baseline) throws {
        guard baseline.schemaVersion == .current else {
            throw LogicalDiffError.invalidBaseline
        }
        var identityIDs: Set<LogicalNodeID> = []
        for record in baseline.identityRecords {
            guard identityIDs.insert(record.logicalNodeID).inserted else {
                throw LogicalDiffError.invalidBaseline
            }
            var sourceIDs: Set<BSESourceID> = []
            for observation in record.observations {
                guard sourceIDs.insert(observation.sourceID).inserted else {
                    throw LogicalDiffError.duplicateObservation(
                        logicalNodeID: record.logicalNodeID,
                        sourceID: observation.sourceID
                    )
                }
            }
        }
    }

    private func validatedSnapshotState(
        _ snapshots: [LogicalSnapshot]
    ) throws -> SnapshotState {
        var observedBySource: [BSESourceID: Set<LogicalNodeID>] = [:]
        var kindsByIdentity: [LogicalNodeID: NodeKind] = [:]

        for snapshot in snapshots.sorted(by: snapshotOrder) {
            guard observedBySource[snapshot.source] == nil else {
                let duplicates = observedBySource[snapshot.source, default: []]
                    .intersection(snapshot.tree.nodes.map(\.logicalID))
                if let duplicate = duplicates.sorted().first {
                    throw LogicalDiffError.duplicateLogicalNode(
                        logicalNodeID: duplicate,
                        sourceID: snapshot.source
                    )
                }
                throw LogicalDiffError.invalidLogicalSnapshot(snapshot.source)
            }

            var sourceIDs: Set<LogicalNodeID> = []
            for node in snapshot.tree.nodes {
                guard sourceIDs.insert(node.logicalID).inserted else {
                    throw LogicalDiffError.duplicateLogicalNode(
                        logicalNodeID: node.logicalID,
                        sourceID: snapshot.source
                    )
                }
                if let existingKind = kindsByIdentity[node.logicalID],
                   existingKind != node.kind {
                    throw LogicalDiffError.inconsistentState(node.logicalID)
                }
                kindsByIdentity[node.logicalID] = node.kind
            }
            observedBySource[snapshot.source] = sourceIDs
        }

        return SnapshotState(
            observedBySource: observedBySource,
            kindsByIdentity: kindsByIdentity
        )
    }

    private func makeObservationChanges(
        for record: IdentityRecord,
        requestedSourceIDs: [BSESourceID],
        observedBySource: [BSESourceID: Set<LogicalNodeID>]
    ) throws -> [LogicalObservationChange] {
        var observations: [BSESourceID: BaselineObservation] = [:]
        for observation in record.observations {
            guard observations.updateValue(
                observation,
                forKey: observation.sourceID
            ) == nil else {
                throw LogicalDiffError.duplicateObservation(
                    logicalNodeID: record.logicalNodeID,
                    sourceID: observation.sourceID
                )
            }
        }

        return requestedSourceIDs.compactMap { sourceID in
            let isObserved = observedBySource[sourceID, default: []].contains(
                record.logicalNodeID
            )
            switch (observations[sourceID]?.presence, isObserved) {
            case (nil, true):
                return .added(logicalNodeID: record.logicalNodeID, sourceID: sourceID)
            case (.absent, true):
                return .restored(logicalNodeID: record.logicalNodeID, sourceID: sourceID)
            case (.present, false):
                return .removed(logicalNodeID: record.logicalNodeID, sourceID: sourceID)
            default:
                return nil
            }
        }
    }

    private func shouldArchive(
        _ record: IdentityRecord,
        requestedSourceIDs: Set<BSESourceID>,
        observedSources: [BSESourceID]
    ) -> Bool {
        guard record.state == .active, observedSources.isEmpty else { return false }
        let presentObservationSources = Set(record.observations.compactMap {
            $0.presence == .present ? $0.sourceID : nil
        })
        return !presentObservationSources.isEmpty
            && presentObservationSources.isSubset(of: requestedSourceIDs)
    }

    private func identityChangeOrder(
        _ lhs: LogicalIdentityChange,
        _ rhs: LogicalIdentityChange
    ) -> Bool {
        if lhs.logicalNodeID != rhs.logicalNodeID {
            return lhs.logicalNodeID < rhs.logicalNodeID
        }
        return identityChangeRank(lhs) < identityChangeRank(rhs)
    }

    private func identityChangeRank(_ change: LogicalIdentityChange) -> Int {
        switch change {
        case .created: 0
        case .updated: 1
        case .archived: 2
        case .reactivated: 3
        }
    }

    private func observationChangeOrder(
        _ lhs: LogicalObservationChange,
        _ rhs: LogicalObservationChange
    ) -> Bool {
        if lhs.logicalNodeID != rhs.logicalNodeID {
            return lhs.logicalNodeID < rhs.logicalNodeID
        }
        let lhsSource = lhs.sourceID.rawValue.uuidString
        let rhsSource = rhs.sourceID.rawValue.uuidString
        if lhsSource != rhsSource { return lhsSource < rhsSource }
        return observationChangeRank(lhs) < observationChangeRank(rhs)
    }

    private func observationChangeRank(_ change: LogicalObservationChange) -> Int {
        switch change {
        case .added: 0
        case .removed: 1
        case .restored: 2
        }
    }

    private func snapshotOrder(_ lhs: LogicalSnapshot, _ rhs: LogicalSnapshot) -> Bool {
        lhs.source.rawValue.uuidString < rhs.source.rawValue.uuidString
    }

    private func makeReport(
        baseline: Baseline,
        snapshotState: SnapshotState,
        identityChanges: [LogicalIdentityChange],
        observationChanges: [LogicalObservationChange],
        unchangedIdentityIDs: [LogicalNodeID]
    ) -> LogicalDiffReport {
        LogicalDiffReport(
            requestedSourceIDs: snapshotState.requestedSourceIDs,
            baselineIdentityCount: baseline.identityRecords.count,
            observedIdentityCount: snapshotState.kindsByIdentity.count,
            createdIdentityCount: identityChanges.count {
                if case .created = $0 { true } else { false }
            },
            updatedIdentityCount: identityChanges.count {
                if case .updated = $0 { true } else { false }
            },
            archivedIdentityCount: identityChanges.count {
                if case .archived = $0 { true } else { false }
            },
            reactivatedIdentityCount: identityChanges.count {
                if case .reactivated = $0 { true } else { false }
            },
            observationChangeCount: observationChanges.count,
            unchangedIdentityCount: unchangedIdentityIDs.count
        )
    }
}

private nonisolated struct SnapshotState: Sendable {
    let observedBySource: [BSESourceID: Set<LogicalNodeID>]
    let kindsByIdentity: [LogicalNodeID: NodeKind]

    var requestedSourceIDs: [BSESourceID] {
        observedBySource.keys.sorted {
            $0.rawValue.uuidString < $1.rawValue.uuidString
        }
    }

    func sourcesContaining(_ logicalNodeID: LogicalNodeID) -> [BSESourceID] {
        observedBySource.compactMap { sourceID, logicalNodeIDs in
            logicalNodeIDs.contains(logicalNodeID) ? sourceID : nil
        }.sorted {
            $0.rawValue.uuidString < $1.rawValue.uuidString
        }
    }
}
