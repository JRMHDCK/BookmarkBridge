//
//  BaselineRepositoryTests.swift
//  BookmarkBridgeTests
//

import Testing
@testable import BookmarkBridge

@Suite("BSE Baseline Repository")
struct BaselineRepositoryTests {
    @Test("Repository saves and loads without implicit transformation")
    func loadAndSave() async throws {
        let store = InMemoryBaselineStore()
        let repository = BaselineRepository(store: store)
        let baseline = try BaselineTestSupport.emptyBaseline()

        try await repository.save(baseline)

        #expect(try await repository.load() == baseline)
    }

    @Test("Successful transaction persists the complete batch")
    func transactionPersists() async throws {
        let baseline = try BaselineTestSupport.emptyBaseline()
        let store = InMemoryBaselineStore(baseline: baseline)
        let repository = BaselineRepository(store: store)
        let firstID = try BaselineTestSupport.logicalID(1)
        let secondID = try BaselineTestSupport.logicalID(2)
        let commands: [BaselineCommand] = [
            .createIdentity(CreateIdentityCommand(logicalNodeID: firstID, observations: [])),
            .createIdentity(CreateIdentityCommand(logicalNodeID: secondID, observations: [])),
        ]

        let changeSet = try await repository.apply(
            commands: commands,
            expectedRevision: .zero
        )

        #expect(changeSet.revisionAfter == BaselineRevision(2))
        #expect(try await repository.load() == changeSet.baseline)
    }

    @Test("Global revision conflict occurs before business logic")
    func revisionConflict() async throws {
        let baseline = try BaselineTestSupport.baselineWithIdentity()
        let store = InMemoryBaselineStore(baseline: baseline)
        let repository = BaselineRepository(store: store)
        let stale = BaselineRevision(0)

        await #expect(throws: BaselineError.revisionConflict(
            expected: stale,
            actual: baseline.revision
        )) {
            _ = try await repository.apply(commands: [], expectedRevision: stale)
        }
        #expect(try await repository.load() == baseline)
    }

    @Test("Business failure rolls back the entire repository transaction")
    func businessFailureRollsBack() async throws {
        let baseline = try BaselineTestSupport.emptyBaseline()
        let store = InMemoryBaselineStore(baseline: baseline)
        let repository = BaselineRepository(store: store)
        let logicalID = try BaselineTestSupport.logicalID(1)
        let duplicateCommands: [BaselineCommand] = [
            .createIdentity(CreateIdentityCommand(logicalNodeID: logicalID, observations: [])),
            .createIdentity(CreateIdentityCommand(logicalNodeID: logicalID, observations: [])),
        ]

        await #expect(throws: BaselineError.identityAlreadyExists(logicalID)) {
            _ = try await repository.apply(
                commands: duplicateCommands,
                expectedRevision: .zero
            )
        }
        #expect(try await repository.load() == baseline)
    }

    @Test("Store failure leaves the previously persisted baseline intact")
    func persistenceFailureRollsBack() async throws {
        let baseline = try BaselineTestSupport.emptyBaseline()
        let store = FailingBaselineStore(baseline: baseline)
        let repository = BaselineRepository(store: store)

        await #expect(throws: BaselineError.storeFailure) {
            _ = try await repository.apply(
                commands: [.createIdentity(CreateIdentityCommand(
                    logicalNodeID: BaselineTestSupport.logicalID(1),
                    observations: []
                ))],
                expectedRevision: .zero
            )
        }
        #expect(try await repository.load() == baseline)
    }

    @Test("Load never performs an implicit migration")
    func migrationIsExplicit() async throws {
        let oldVersion = BaselineSchemaVersion(0)
        let baseline = try BaselineTestSupport.emptyBaseline(schemaVersion: oldVersion)
        let store = InMemoryBaselineStore(baseline: baseline)
        let repository = BaselineRepository(
            store: store,
            migrations: [TestBaselineMigration()]
        )

        let loaded = try await repository.load()

        #expect(loaded?.schemaVersion == oldVersion)
        #expect(loaded?.revision == .zero)
        await #expect(throws: BaselineError.migrationRequired(
            current: oldVersion,
            required: .current
        )) {
            _ = try await repository.apply(commands: [], expectedRevision: .zero)
        }

        let migrated = try await repository.migrate(to: .current)

        #expect(migrated.schemaVersion == .current)
        #expect(migrated.revision == BaselineRevision(1))
        #expect(migrated.baselineID == baseline.baselineID)
        #expect(migrated.metadata.migrationHistory == [BaselineMigrationRecord(
            sourceVersion: oldVersion,
            destinationVersion: .current
        )])
        #expect(try await repository.load() == migrated)
    }

    @Test("Missing migration path fails without changing storage")
    func missingMigrationPath() async throws {
        let oldVersion = BaselineSchemaVersion(0)
        let baseline = try BaselineTestSupport.emptyBaseline(schemaVersion: oldVersion)
        let store = InMemoryBaselineStore(baseline: baseline)
        let repository = BaselineRepository(store: store)

        await #expect(throws: BaselineError.migrationPathNotFound(
            from: oldVersion,
            to: .current
        )) {
            _ = try await repository.migrate(to: .current)
        }
        #expect(try await repository.load() == baseline)
    }

    @Test("Empty transaction is a deterministic non-persisting no-op")
    func emptyTransaction() async throws {
        let baseline = try BaselineTestSupport.emptyBaseline()
        let store = CountingBaselineStore(baseline: baseline)
        let repository = BaselineRepository(store: store)

        let result = try await repository.apply(commands: [], expectedRevision: .zero)

        #expect(result.baseline == baseline)
        #expect(result.executedCommands.isEmpty)
        #expect(await store.saveCount() == 0)
    }
}

private nonisolated struct TestBaselineMigration: BaselineMigration {
    let sourceVersion = BaselineSchemaVersion(0)
    let destinationVersion = BaselineSchemaVersion.current

    func migrate(_ baseline: Baseline) throws -> Baseline {
        try Baseline(
            baselineID: baseline.baselineID,
            schemaVersion: destinationVersion,
            revision: baseline.revision.incremented(),
            identityRecords: baseline.identityRecords,
            metadata: baseline.metadata
        )
    }
}

private actor FailingBaselineStore: BaselineStore {
    private let baseline: Baseline

    init(baseline: Baseline) {
        self.baseline = baseline
    }

    func load() async throws -> Baseline? { baseline }

    func save(
        _ baseline: Baseline,
        expectedRevision: BaselineRevision?
    ) async throws {
        throw BaselineError.storeFailure
    }
}

private actor CountingBaselineStore: BaselineStore {
    private let baseline: Baseline
    private var storedSaveCount = 0

    init(baseline: Baseline) {
        self.baseline = baseline
    }

    func load() async throws -> Baseline? { baseline }

    func save(
        _ baseline: Baseline,
        expectedRevision: BaselineRevision?
    ) async throws {
        storedSaveCount += 1
    }

    func saveCount() -> Int { storedSaveCount }
}
