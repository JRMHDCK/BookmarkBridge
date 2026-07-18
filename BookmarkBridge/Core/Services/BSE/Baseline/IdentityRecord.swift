//
//  IdentityRecord.swift
//  BookmarkBridge
//

import Foundation

nonisolated enum IdentityRecordState: String, Hashable, Codable, Sendable {
    case active
    case archived
    case deleted
}

/// Internal revision provenance, independent of browsers and persistence.
nonisolated struct IdentityRecordMetadata: Hashable, Codable, Sendable {
    let createdInBaselineRevision: BaselineRevision
    let lastChangedInBaselineRevision: BaselineRevision
}

/// Exactly one durable logical object known to BSE.
nonisolated struct IdentityRecord: Hashable, Codable, Sendable {
    let logicalNodeID: LogicalNodeID
    let revision: IdentityRevision
    let state: IdentityRecordState
    let observations: [BaselineObservation]
    let metadata: IdentityRecordMetadata

    init(
        logicalNodeID: LogicalNodeID,
        revision: IdentityRevision,
        state: IdentityRecordState,
        observations: [BaselineObservation],
        metadata: IdentityRecordMetadata
    ) throws {
        var sourceIDs: Set<BSESourceID> = []
        for observation in observations {
            guard sourceIDs.insert(observation.sourceID).inserted else {
                throw BaselineError.invariantViolation(.duplicateObservationSource)
            }
        }
        guard metadata.createdInBaselineRevision <= metadata.lastChangedInBaselineRevision else {
            throw BaselineError.invariantViolation(.invalidIdentityMetadata)
        }
        self.logicalNodeID = logicalNodeID
        self.revision = revision
        self.state = state
        self.observations = observations.sorted { lhs, rhs in
            lhs.sourceID.rawValue.uuidString < rhs.sourceID.rawValue.uuidString
        }
        self.metadata = metadata
    }

    init(from decoder: any Decoder) throws {
        let values = try Values(from: decoder)
        do {
            try self.init(
                logicalNodeID: values.logicalNodeID,
                revision: values.revision,
                state: values.state,
                observations: values.observations,
                metadata: values.metadata
            )
        } catch {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Invalid identity record")
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        try Values(
            logicalNodeID: logicalNodeID,
            revision: revision,
            state: state,
            observations: observations,
            metadata: metadata
        ).encode(to: encoder)
    }

    private struct Values: Codable {
        let logicalNodeID: LogicalNodeID
        let revision: IdentityRevision
        let state: IdentityRecordState
        let observations: [BaselineObservation]
        let metadata: IdentityRecordMetadata
    }
}
