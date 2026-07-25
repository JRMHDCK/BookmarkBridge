//
//  BaselineRepository.swift
//  BookmarkBridge
//

/// Coordinates loading, conditional persistence, explicit migrations, and
/// atomic application. It contains no identity business rules.
nonisolated struct BaselineRepository: Sendable {
    private let store: any BaselineStore
    private let engine: BaselineEngine
    private let requiredSchemaVersion: BaselineSchemaVersion
    private let migrations: [any BaselineMigration]

    init(
        store: any BaselineStore,
        engine: BaselineEngine = BaselineEngine(),
        requiredSchemaVersion: BaselineSchemaVersion = .current,
        migrations: [any BaselineMigration] = []
    ) {
        self.store = store
        self.engine = engine
        self.requiredSchemaVersion = requiredSchemaVersion
        self.migrations = migrations
    }

    /// Loads exactly what is stored. It never migrates implicitly.
    func load() async throws -> Baseline? {
        try await store.load()
    }

    func save(
        _ baseline: Baseline,
        expectedRevision: BaselineRevision? = nil
    ) async throws {
        try await store.save(baseline, expectedRevision: expectedRevision)
    }

    /// Captures the exact persisted Baseline used by the global transaction.
    func transactionSnapshot() async throws -> Baseline? {
        try await store.load()
    }

    /// Restores a previously captured value without applying business
    /// commands or monotonic revision validation.
    func restoreTransactionSnapshot(_ baseline: Baseline?) async throws {
        guard let transactionStore = store as? any BaselineTransactionStore else {
            throw BaselineError.transactionUnsupported
        }
        try await transactionStore.restoreTransactionSnapshot(baseline)
    }

    /// Applies and persists one command batch with optimistic revision control.
    func apply(
        commands: [BaselineCommand],
        expectedRevision: BaselineRevision
    ) async throws -> BaselineChangeSet {
        guard let baseline = try await store.load() else {
            throw BaselineError.baselineNotFound
        }
        guard baseline.revision == expectedRevision else {
            throw BaselineError.revisionConflict(
                expected: expectedRevision,
                actual: baseline.revision
            )
        }
        guard baseline.schemaVersion == requiredSchemaVersion else {
            throw BaselineError.migrationRequired(
                current: baseline.schemaVersion,
                required: requiredSchemaVersion
            )
        }

        let changeSet = try engine.apply(commands: commands, to: baseline)
        guard !commands.isEmpty else { return changeSet }
        try await store.save(
            changeSet.baseline,
            expectedRevision: baseline.revision
        )
        return changeSet
    }

    /// Executes a complete migration path only when called explicitly.
    func migrate(to targetVersion: BaselineSchemaVersion) async throws -> Baseline {
        guard let original = try await store.load() else {
            throw BaselineError.baselineNotFound
        }
        guard original.schemaVersion != targetVersion else { return original }

        var migrated = original
        var visited: Set<BaselineSchemaVersion> = [original.schemaVersion]
        while migrated.schemaVersion != targetVersion {
            guard let migration = migrations.first(where: {
                $0.sourceVersion == migrated.schemaVersion
            }) else {
                throw BaselineError.migrationPathNotFound(
                    from: migrated.schemaVersion,
                    to: targetVersion
                )
            }
            guard !visited.contains(migration.destinationVersion) else {
                throw BaselineError.invariantViolation(.invalidMigrationResult)
            }

            let previous = migrated
            let result = try migration.migrate(previous)
            guard result.baselineID == previous.baselineID,
                  result.schemaVersion == migration.destinationVersion,
                  previous.revision < result.revision else {
                throw BaselineError.invariantViolation(.invalidMigrationResult)
            }
            let history = previous.metadata.migrationHistory + [
                BaselineMigrationRecord(
                    sourceVersion: migration.sourceVersion,
                    destinationVersion: migration.destinationVersion
                ),
            ]
            migrated = try Baseline(
                baselineID: result.baselineID,
                schemaVersion: result.schemaVersion,
                revision: result.revision,
                identityRecords: result.identityRecords,
                metadata: BaselineMetadata(migrationHistory: history)
            )
            visited.insert(migrated.schemaVersion)
        }

        try await store.save(migrated, expectedRevision: original.revision)
        return migrated
    }
}
