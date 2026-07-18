//
//  RecognitionArtifact.swift
//  BookmarkBridge
//

import Foundation

nonisolated enum RecognitionArtifactKindError: Error, Hashable, Sendable {
    case empty
}

/// Extensible identifier for an opaque recognition artifact family.
nonisolated struct RecognitionArtifactKind: Hashable, Codable, Sendable {
    let rawValue: String

    init(_ rawValue: String) throws {
        guard !rawValue.isEmpty else {
            throw RecognitionArtifactKindError.empty
        }
        self.rawValue = rawValue
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        do {
            try self.init(value)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Recognition artifact kind cannot be empty"
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Versioned opaque bytes retained by the baseline without interpretation.
nonisolated struct RecognitionArtifact: Hashable, Codable, Sendable {
    let kind: RecognitionArtifactKind
    let version: UInt64
    let payload: Data

    init(kind: RecognitionArtifactKind, version: UInt64, payload: Data) {
        self.kind = kind
        self.version = version
        self.payload = payload
    }
}
