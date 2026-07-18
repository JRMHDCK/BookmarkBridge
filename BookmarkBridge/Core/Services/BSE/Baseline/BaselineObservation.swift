//
//  BaselineObservation.swift
//  BookmarkBridge
//

import Foundation

nonisolated enum BaselineObservationPresence: String, Hashable, Codable, Sendable {
    case present
    case absent
}

/// Source-local evidence attached to one durable logical identity.
///
/// It intentionally contains no title, URL, hierarchy, snapshot, browser type,
/// or native browser data.
nonisolated struct BaselineObservation: Hashable, Codable, Sendable {
    let sourceID: BSESourceID
    let provisionalLogicalID: LogicalNodeID
    let recognitionArtifacts: [RecognitionArtifact]
    let firstObservedAt: Date
    let lastObservedAt: Date
    let presence: BaselineObservationPresence

    init(
        sourceID: BSESourceID,
        provisionalLogicalID: LogicalNodeID,
        recognitionArtifacts: [RecognitionArtifact],
        firstObservedAt: Date,
        lastObservedAt: Date,
        presence: BaselineObservationPresence
    ) throws {
        guard firstObservedAt <= lastObservedAt else {
            throw BaselineError.invariantViolation(.invalidObservationInterval)
        }
        self.sourceID = sourceID
        self.provisionalLogicalID = provisionalLogicalID
        self.recognitionArtifacts = recognitionArtifacts
        self.firstObservedAt = firstObservedAt
        self.lastObservedAt = lastObservedAt
        self.presence = presence
    }

    init(from decoder: any Decoder) throws {
        let values = try Values(from: decoder)
        do {
            try self.init(
                sourceID: values.sourceID,
                provisionalLogicalID: values.provisionalLogicalID,
                recognitionArtifacts: values.recognitionArtifacts,
                firstObservedAt: values.firstObservedAt,
                lastObservedAt: values.lastObservedAt,
                presence: values.presence
            )
        } catch {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Invalid baseline observation")
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        try Values(
            sourceID: sourceID,
            provisionalLogicalID: provisionalLogicalID,
            recognitionArtifacts: recognitionArtifacts,
            firstObservedAt: firstObservedAt,
            lastObservedAt: lastObservedAt,
            presence: presence
        ).encode(to: encoder)
    }

    private struct Values: Codable {
        let sourceID: BSESourceID
        let provisionalLogicalID: LogicalNodeID
        let recognitionArtifacts: [RecognitionArtifact]
        let firstObservedAt: Date
        let lastObservedAt: Date
        let presence: BaselineObservationPresence
    }
}
