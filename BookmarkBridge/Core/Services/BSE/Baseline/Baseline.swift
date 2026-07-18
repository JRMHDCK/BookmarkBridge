//
//  Baseline.swift
//  BookmarkBridge
//

/// Internal baseline metadata. Migration history is explicit and browser-free.
nonisolated struct BaselineMetadata: Hashable, Codable, Sendable {
    let migrationHistory: [BaselineMigrationRecord]

    init(migrationHistory: [BaselineMigrationRecord] = []) {
        self.migrationHistory = migrationHistory
    }
}

/// Immutable persistent registry of durable BSE logical identities.
nonisolated struct Baseline: Hashable, Codable, Sendable {
    let baselineID: BaselineID
    let schemaVersion: BaselineSchemaVersion
    let revision: BaselineRevision
    let identityRecords: [IdentityRecord]
    let metadata: BaselineMetadata

    init(
        baselineID: BaselineID,
        schemaVersion: BaselineSchemaVersion,
        revision: BaselineRevision,
        identityRecords: [IdentityRecord],
        metadata: BaselineMetadata = BaselineMetadata()
    ) throws {
        var identifiers: Set<LogicalNodeID> = []
        for record in identityRecords {
            guard identifiers.insert(record.logicalNodeID).inserted else {
                throw BaselineError.invariantViolation(.duplicateLogicalNodeID)
            }
            guard record.metadata.lastChangedInBaselineRevision <= revision else {
                throw BaselineError.invariantViolation(.identityRevisionBeyondBaseline)
            }
        }
        self.baselineID = baselineID
        self.schemaVersion = schemaVersion
        self.revision = revision
        self.identityRecords = identityRecords.sorted { $0.logicalNodeID < $1.logicalNodeID }
        self.metadata = metadata
    }

    static func empty(
        baselineID: BaselineID,
        schemaVersion: BaselineSchemaVersion = .current
    ) throws -> Baseline {
        try Baseline(
            baselineID: baselineID,
            schemaVersion: schemaVersion,
            revision: .zero,
            identityRecords: []
        )
    }

    func identity(_ logicalNodeID: LogicalNodeID) -> IdentityRecord? {
        identityRecords.first { $0.logicalNodeID == logicalNodeID }
    }

    init(from decoder: any Decoder) throws {
        let values = try Values(from: decoder)
        do {
            try self.init(
                baselineID: values.baselineID,
                schemaVersion: values.schemaVersion,
                revision: values.revision,
                identityRecords: values.identityRecords,
                metadata: values.metadata
            )
        } catch {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Invalid baseline")
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        try Values(
            baselineID: baselineID,
            schemaVersion: schemaVersion,
            revision: revision,
            identityRecords: identityRecords,
            metadata: metadata
        ).encode(to: encoder)
    }

    private struct Values: Codable {
        let baselineID: BaselineID
        let schemaVersion: BaselineSchemaVersion
        let revision: BaselineRevision
        let identityRecords: [IdentityRecord]
        let metadata: BaselineMetadata
    }
}
