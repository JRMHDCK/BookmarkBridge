//
//  BaselineEngine.swift
//  BookmarkBridge
//

/// Pure deterministic business logic for durable baseline identities.
nonisolated struct BaselineEngine: Sendable {
    func apply(
        commands: [BaselineCommand],
        to baseline: Baseline
    ) throws -> BaselineChangeSet {
        var records = baseline.identityRecords
        var revision = baseline.revision
        var createdIdentities: [LogicalNodeID] = []
        var modifiedIdentities: [LogicalNodeID] = []
        var modifiedSet: Set<LogicalNodeID> = []

        for command in commands {
            let nextRevision = try revision.incremented()
            switch command {
            case .createIdentity(let value):
                guard !records.contains(where: { $0.logicalNodeID == value.logicalNodeID }) else {
                    throw BaselineError.identityAlreadyExists(value.logicalNodeID)
                }
                try validateUniqueObservations(
                    value.observations,
                    logicalNodeID: value.logicalNodeID
                )
                let identityRevision = try IdentityRevision(1)
                records.append(try IdentityRecord(
                    logicalNodeID: value.logicalNodeID,
                    revision: identityRevision,
                    state: .active,
                    observations: value.observations,
                    metadata: IdentityRecordMetadata(
                        createdInBaselineRevision: nextRevision,
                        lastChangedInBaselineRevision: nextRevision
                    )
                ))
                createdIdentities.append(value.logicalNodeID)

            case .updateObservation(let value):
                let index = try recordIndex(value.logicalNodeID, in: records)
                let current = records[index]
                try validateRevision(
                    value.expectedIdentityRevision,
                    for: current
                )
                try requireActive(current)

                var observations = current.observations
                if let observationIndex = observations.firstIndex(where: {
                    $0.sourceID == value.observation.sourceID
                }) {
                    let previous = observations[observationIndex]
                    guard previous.firstObservedAt == value.observation.firstObservedAt,
                          previous.lastObservedAt <= value.observation.lastObservedAt else {
                        throw BaselineError.invariantViolation(.invalidObservationInterval)
                    }
                    observations[observationIndex] = value.observation
                } else {
                    observations.append(value.observation)
                }
                records[index] = try changedRecord(
                    current,
                    observations: observations,
                    baselineRevision: nextRevision
                )
                appendModified(value.logicalNodeID, to: &modifiedIdentities, set: &modifiedSet)

            case .replaceRecognitionArtifacts(let value):
                let index = try recordIndex(value.logicalNodeID, in: records)
                let current = records[index]
                try validateRevision(value.expectedIdentityRevision, for: current)
                try requireActive(current)

                var observations = current.observations
                guard let observationIndex = observations.firstIndex(where: {
                    $0.sourceID == value.sourceID
                }) else {
                    throw BaselineError.observationNotFound(
                        logicalNodeID: value.logicalNodeID,
                        sourceID: value.sourceID
                    )
                }
                let observation = observations[observationIndex]
                observations[observationIndex] = try BaselineObservation(
                    sourceID: observation.sourceID,
                    provisionalLogicalID: observation.provisionalLogicalID,
                    recognitionArtifacts: value.recognitionArtifacts,
                    firstObservedAt: observation.firstObservedAt,
                    lastObservedAt: observation.lastObservedAt,
                    presence: observation.presence
                )
                records[index] = try changedRecord(
                    current,
                    observations: observations,
                    baselineRevision: nextRevision
                )
                appendModified(value.logicalNodeID, to: &modifiedIdentities, set: &modifiedSet)

            case .archiveIdentity(let value):
                let index = try recordIndex(value.logicalNodeID, in: records)
                let current = records[index]
                try validateRevision(value.expectedIdentityRevision, for: current)
                records[index] = try transition(
                    current,
                    to: .archived,
                    allowedFrom: [.active],
                    baselineRevision: nextRevision
                )
                appendModified(value.logicalNodeID, to: &modifiedIdentities, set: &modifiedSet)

            case .markIdentityDeleted(let value):
                let index = try recordIndex(value.logicalNodeID, in: records)
                let current = records[index]
                try validateRevision(value.expectedIdentityRevision, for: current)
                records[index] = try transition(
                    current,
                    to: .deleted,
                    allowedFrom: [.active, .archived],
                    baselineRevision: nextRevision
                )
                appendModified(value.logicalNodeID, to: &modifiedIdentities, set: &modifiedSet)

            case .reactivateIdentity(let value):
                let index = try recordIndex(value.logicalNodeID, in: records)
                let current = records[index]
                try validateRevision(value.expectedIdentityRevision, for: current)
                records[index] = try transition(
                    current,
                    to: .active,
                    allowedFrom: [.archived, .deleted],
                    baselineRevision: nextRevision
                )
                appendModified(value.logicalNodeID, to: &modifiedIdentities, set: &modifiedSet)
            }
            revision = nextRevision
        }

        let updatedBaseline = try Baseline(
            baselineID: baseline.baselineID,
            schemaVersion: baseline.schemaVersion,
            revision: revision,
            identityRecords: records,
            metadata: baseline.metadata
        )
        return BaselineChangeSet(
            baseline: updatedBaseline,
            createdIdentities: createdIdentities,
            modifiedIdentities: modifiedIdentities,
            revisionBefore: baseline.revision,
            revisionAfter: revision,
            executedCommands: commands
        )
    }

    private func validateUniqueObservations(
        _ observations: [BaselineObservation],
        logicalNodeID: LogicalNodeID
    ) throws {
        var sources: Set<BSESourceID> = []
        for observation in observations {
            guard sources.insert(observation.sourceID).inserted else {
                throw BaselineError.duplicateObservation(
                    logicalNodeID: logicalNodeID,
                    sourceID: observation.sourceID
                )
            }
        }
    }

    private func recordIndex(
        _ logicalNodeID: LogicalNodeID,
        in records: [IdentityRecord]
    ) throws -> Int {
        guard let index = records.firstIndex(where: { $0.logicalNodeID == logicalNodeID }) else {
            throw BaselineError.identityNotFound(logicalNodeID)
        }
        return index
    }

    private func validateRevision(
        _ expected: IdentityRevision,
        for record: IdentityRecord
    ) throws {
        guard record.revision == expected else {
            throw BaselineError.identityRevisionConflict(
                logicalNodeID: record.logicalNodeID,
                expected: expected,
                actual: record.revision
            )
        }
    }

    private func requireActive(_ record: IdentityRecord) throws {
        guard record.state == .active else {
            throw BaselineError.invalidLifecycleTransition(
                logicalNodeID: record.logicalNodeID,
                from: record.state,
                to: .active
            )
        }
    }

    private func changedRecord(
        _ record: IdentityRecord,
        observations: [BaselineObservation],
        baselineRevision: BaselineRevision
    ) throws -> IdentityRecord {
        try IdentityRecord(
            logicalNodeID: record.logicalNodeID,
            revision: record.revision.incremented(),
            state: record.state,
            observations: observations,
            metadata: IdentityRecordMetadata(
                createdInBaselineRevision: record.metadata.createdInBaselineRevision,
                lastChangedInBaselineRevision: baselineRevision
            )
        )
    }

    private func transition(
        _ record: IdentityRecord,
        to target: IdentityRecordState,
        allowedFrom: Set<IdentityRecordState>,
        baselineRevision: BaselineRevision
    ) throws -> IdentityRecord {
        guard allowedFrom.contains(record.state) else {
            throw BaselineError.invalidLifecycleTransition(
                logicalNodeID: record.logicalNodeID,
                from: record.state,
                to: target
            )
        }
        return try IdentityRecord(
            logicalNodeID: record.logicalNodeID,
            revision: record.revision.incremented(),
            state: target,
            observations: record.observations,
            metadata: IdentityRecordMetadata(
                createdInBaselineRevision: record.metadata.createdInBaselineRevision,
                lastChangedInBaselineRevision: baselineRevision
            )
        )
    }

    private func appendModified(
        _ logicalNodeID: LogicalNodeID,
        to values: inout [LogicalNodeID],
        set: inout Set<LogicalNodeID>
    ) {
        if set.insert(logicalNodeID).inserted {
            values.append(logicalNodeID)
        }
    }
}
