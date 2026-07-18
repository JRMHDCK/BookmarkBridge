//
//  BaselineMigration.swift
//  BookmarkBridge
//

/// Audit metadata for one explicitly executed schema migration.
nonisolated struct BaselineMigrationRecord: Hashable, Codable, Sendable {
    let sourceVersion: BaselineSchemaVersion
    let destinationVersion: BaselineSchemaVersion
}

/// One explicit, deterministic schema transition. Repository code only selects
/// and validates migrations; the migration owns its version-specific mapping.
nonisolated protocol BaselineMigration: Sendable {
    var sourceVersion: BaselineSchemaVersion { get }
    var destinationVersion: BaselineSchemaVersion { get }

    func migrate(_ baseline: Baseline) throws -> Baseline
}
