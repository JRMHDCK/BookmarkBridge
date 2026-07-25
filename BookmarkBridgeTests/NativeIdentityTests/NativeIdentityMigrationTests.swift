//
//  NativeIdentityMigrationTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("BSE-795A Chrome Native Identity Migration")
struct NativeIdentityMigrationTests {
    @Test("A verified Chrome id fallback migrates atomically to its GUID")
    func validMigration() throws {
        let old = mapping(logical: 1, native: "id:42")
        let repository = InMemoryNativeIdentityRepository(mappings: [old])

        let result = try repository.applyAtomically([
            .migrate(migration(
                logical: old.logicalNodeID,
                from: "id:42",
                to: "guid:abc",
                proof: "id:42"
            )),
        ])

        #expect(result.migrationsApplied == 1)
        #expect(repository.nativeIdentifier(
            for: old.logicalNodeID,
            sourceID: old.sourceID
        ) == NativeNodeIdentifier("guid:abc"))
        #expect(repository.logicalNodeID(
            for: NativeNodeIdentifier("guid:abc"),
            sourceID: old.sourceID
        ) == old.logicalNodeID)
        #expect(repository.logicalNodeID(
            for: NativeNodeIdentifier("id:42"),
            sourceID: old.sourceID
        ) == nil)
    }

    @Test("Bootstrap detects the exact id fallback to GUID transition")
    func bootstrapMigration() throws {
        let durableID = logicalID(1)
        let provisionalID = logicalID(101)
        let repository = InMemoryNativeIdentityRepository(mappings: [
            mapping(logical: 1, native: "id:42"),
        ])
        let resolved = try ChromeNativeIdentifierResolver().resolve(
            chromeID: "42",
            chromeGUID: "abc"
        )
        let observation = NativeIdentityObservation(
            sourceID: sourceID,
            provisionalLogicalNodeID: provisionalID,
            nativeIdentifier: resolved.nativeIdentifier,
            nativeIdentityKind: resolved.kind,
            continuityIdentifier: resolved.continuityIdentifier,
            continuityIdentityKind: resolved.continuityKind
        )

        let result = try NativeIdentityBootstrapper(
            repository: repository
        ).bootstrap(
            reconciliationReport: report(
                observation: observation,
                durableID: durableID
            ),
            observations: [observation]
        )

        #expect(result.migrationsApplied == 1)
        #expect(result.mappingsCreated == 0)
        #expect(repository.nativeIdentifier(
            for: durableID,
            sourceID: sourceID
        ) == observation.nativeIdentifier)
    }

    @Test("A different Chrome id cannot prove continuity")
    func differentChromeIDIsRejected() {
        let old = mapping(logical: 1, native: "id:42")
        let repository = InMemoryNativeIdentityRepository(mappings: [old])

        #expect(throws: NativeIdentityMigrationError.self) {
            try repository.applyAtomically([
                .migrate(migration(
                    logical: old.logicalNodeID,
                    from: "id:42",
                    to: "guid:abc",
                    proof: "id:43"
                )),
            ])
        }
        expect(repository, stillContains: old)
    }

    @Test("A GUID already owned by another identity is rejected")
    func GUIDAlreadyUsedIsRejected() {
        let old = mapping(logical: 1, native: "id:42")
        let occupied = mapping(logical: 2, native: "guid:abc")
        let repository = InMemoryNativeIdentityRepository(
            mappings: [old, occupied]
        )

        #expect(throws: NativeIdentityMigrationError.self) {
            try repository.applyAtomically([
                .migrate(migration(
                    logical: old.logicalNodeID,
                    from: "id:42",
                    to: "guid:abc",
                    proof: "id:42"
                )),
            ])
        }
        expect(repository, stillContains: old)
        expect(repository, stillContains: occupied)
    }

    @Test("An old id owned by another durable identity is rejected")
    func oldIDOwnedElsewhereIsRejected() {
        let owner = mapping(logical: 2, native: "id:42")
        let repository = InMemoryNativeIdentityRepository(mappings: [owner])

        #expect(throws: NativeIdentityMigrationError.self) {
            try repository.applyAtomically([
                .migrate(migration(
                    logical: logicalID(1),
                    from: "id:42",
                    to: "guid:abc",
                    proof: "id:42"
                )),
            ])
        }
        expect(repository, stillContains: owner)
    }

    @Test(
        "Only the Chrome idFallback to GUID direction is accepted",
        arguments: [
            (NativeIdentityKind.chromeGUID, NativeIdentityKind.chromeGUID),
            (NativeIdentityKind.chromeGUID, NativeIdentityKind.chromeIDFallback),
            (NativeIdentityKind.opaque, NativeIdentityKind.chromeGUID),
        ]
    )
    func invalidDirectionsAreRejected(
        fromKind: NativeIdentityKind,
        toKind: NativeIdentityKind
    ) {
        let old = mapping(logical: 1, native: "id:42")
        let repository = InMemoryNativeIdentityRepository(mappings: [old])
        let value = NativeIdentityMigration(
            logicalNodeID: old.logicalNodeID,
            sourceID: sourceID,
            from: old.nativeIdentifier,
            fromKind: fromKind,
            to: NativeNodeIdentifier("guid:def"),
            toKind: toKind,
            continuityProof: old.nativeIdentifier,
            continuityProofKind: .chromeIDFallback
        )

        #expect(throws: NativeIdentityMigrationError.self) {
            try repository.applyAtomically([.migrate(value)])
        }
        expect(repository, stillContains: old)
    }

    @Test("Normal registrations and a migration commit in one batch")
    func mixedBatch() throws {
        let old = mapping(logical: 1, native: "id:42")
        let added = mapping(logical: 2, native: "guid:new")
        let repository = InMemoryNativeIdentityRepository(mappings: [old])

        let result = try repository.applyAtomically([
            .register(added),
            .migrate(migration(
                logical: old.logicalNodeID,
                from: "id:42",
                to: "guid:abc",
                proof: "id:42"
            )),
        ])

        #expect(result.registrationsApplied == 1)
        #expect(result.migrationsApplied == 1)
        expect(repository, stillContains: added)
        #expect(repository.nativeIdentifier(
            for: old.logicalNodeID,
            sourceID: sourceID
        ) == NativeNodeIdentifier("guid:abc"))
    }

    @Test("An invalid migration leaves every batch mutation unapplied")
    func invalidBatchIsAtomic() {
        let old = mapping(logical: 1, native: "id:42")
        let added = mapping(logical: 2, native: "guid:new")
        let repository = InMemoryNativeIdentityRepository(mappings: [old])

        #expect(throws: NativeIdentityMigrationError.self) {
            try repository.applyAtomically([
                .register(added),
                .migrate(migration(
                    logical: old.logicalNodeID,
                    from: "id:42",
                    to: "guid:abc",
                    proof: "id:wrong"
                )),
            ])
        }

        expect(repository, stillContains: old)
        #expect(repository.nativeIdentifier(
            for: added.logicalNodeID,
            sourceID: sourceID
        ) == nil)
    }

    @Test("Concurrent migrations to one GUID have exactly one winner")
    func concurrentMigrationsAreAtomic() async {
        let first = mapping(logical: 1, native: "id:41")
        let second = mapping(logical: 2, native: "id:42")
        let repository = InMemoryNativeIdentityRepository(
            mappings: [first, second]
        )

        let successes = await withTaskGroup(of: Bool.self) { group in
            for mapping in [first, second] {
                group.addTask {
                    do {
                        _ = try repository.applyAtomically([
                            .migrate(migration(
                                logical: mapping.logicalNodeID,
                                from: mapping.nativeIdentifier.rawValue,
                                to: "guid:shared",
                                proof: mapping.nativeIdentifier.rawValue
                            )),
                        ])
                        return true
                    } catch {
                        return false
                    }
                }
            }
            return await group.reduce(0) { $0 + ($1 ? 1 : 0) }
        }

        #expect(successes == 1)
        let owner = repository.logicalNodeID(
            for: NativeNodeIdentifier("guid:shared"),
            sourceID: sourceID
        )
        #expect(owner == first.logicalNodeID || owner == second.logicalNodeID)
        let remainingOldMappings = [first, second].count {
            repository.logicalNodeID(
                for: $0.nativeIdentifier,
                sourceID: sourceID
            ) != nil
        }
        #expect(remainingOldMappings == 1)
    }

    @Test("A snapshot restores the id fallback after a GUID migration")
    func migrationRollback() throws {
        let old = mapping(logical: 1, native: "id:42")
        let repository = InMemoryNativeIdentityRepository(mappings: [old])
        let snapshot = try repository.transactionSnapshot()

        _ = try repository.applyAtomically([
            .migrate(migration(
                logical: old.logicalNodeID,
                from: "id:42",
                to: "guid:abc",
                proof: "id:42"
            )),
        ])
        try repository.restore(transactionSnapshot: snapshot)

        expect(repository, stillContains: old)
        #expect(repository.logicalNodeID(
            for: NativeNodeIdentifier("guid:abc"),
            sourceID: sourceID
        ) == nil)
        #expect(try repository.transactionSnapshot() == snapshot)
    }

    @Test("Migration contracts are deterministic and Sendable")
    func deterministicAndSendable() throws {
        let value = migration(
            logical: logicalID(1),
            from: "id:42",
            to: "guid:abc",
            proof: "id:42"
        )
        let first = InMemoryNativeIdentityRepository(mappings: [
            mapping(logical: 1, native: "id:42"),
        ])
        let second = InMemoryNativeIdentityRepository(mappings: [
            mapping(logical: 1, native: "id:42"),
        ])

        let firstResult = try first.applyAtomically([.migrate(value)])
        let secondResult = try second.applyAtomically([.migrate(value)])

        #expect(firstResult == secondResult)
        requireSendable(value)
        requireSendable(firstResult)
        requireSendable(NativeIdentityKind.chromeGUID)
    }

    private func expect(
        _ repository: InMemoryNativeIdentityRepository,
        stillContains mapping: NativeIdentityMapping
    ) {
        #expect(repository.nativeIdentifier(
            for: mapping.logicalNodeID,
            sourceID: mapping.sourceID
        ) == mapping.nativeIdentifier)
        #expect(repository.logicalNodeID(
            for: mapping.nativeIdentifier,
            sourceID: mapping.sourceID
        ) == mapping.logicalNodeID)
    }

    private func report(
        observation: NativeIdentityObservation,
        durableID: LogicalNodeID
    ) -> IdentityReconciliationReport {
        IdentityReconciliationReport(
            createdIdentities: [],
            reusedIdentities: [ReusedIdentityReport(
                logicalNodeID: durableID,
                members: [IdentityNodeReference(
                    sourceID: observation.sourceID,
                    provisionalLogicalID:
                        observation.provisionalLogicalNodeID
                )]
            )],
            ambiguities: [],
            unresolvedObjects: [],
            diagnostics: [],
            statistics: IdentityReconciliationStatistics(
                snapshotCount: 1,
                logicalSnapshotCount: 1,
                groupCount: 1,
                createdIdentityCount: 0,
                reusedIdentityCount: 1,
                ambiguityCount: 0,
                unresolvedObjectCount: 0,
                baselineCommandCount: 0
            )
        )
    }

    private func migration(
        logical: LogicalNodeID,
        from: String,
        to: String,
        proof: String
    ) -> NativeIdentityMigration {
        NativeIdentityMigration(
            logicalNodeID: logical,
            sourceID: sourceID,
            from: NativeNodeIdentifier(from),
            fromKind: .chromeIDFallback,
            to: NativeNodeIdentifier(to),
            toKind: .chromeGUID,
            continuityProof: NativeNodeIdentifier(proof),
            continuityProofKind: .chromeIDFallback
        )
    }

    private func mapping(
        logical: Int,
        native: String
    ) -> NativeIdentityMapping {
        NativeIdentityMapping(
            logicalNodeID: logicalID(logical),
            sourceID: sourceID,
            nativeIdentifier: NativeNodeIdentifier(native)
        )
    }

    private var sourceID: BSESourceID {
        BSESourceID(UUID(
            uuidString: "FB000000-0000-0000-0000-000000000001"
        )!)
    }

    private func logicalID(_ value: Int) -> LogicalNodeID {
        LogicalNodeID(UUID(uuidString: String(
            format: "FB100000-0000-0000-0000-%012d",
            value
        ))!)
    }

    private func requireSendable<T: Sendable>(_ value: T) {
        _ = value
    }
}
