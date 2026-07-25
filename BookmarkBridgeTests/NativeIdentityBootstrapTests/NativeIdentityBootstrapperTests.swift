//
//  NativeIdentityBootstrapperTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Synchronization
import Testing
@testable import BookmarkBridge

@Suite("BSE Native Identity Bootstrap")
struct NativeIdentityBootstrapperTests {
    @Test("An empty repository receives every validated correspondence")
    func emptyRepository() throws {
        let sourceID = sourceID(1)
        let observation = observation(source: sourceID, provisional: 1, native: "native-1")
        let durableID = logicalID(101)
        let repository = RecordingRepository()

        let result = try NativeIdentityBootstrapper(repository: repository).bootstrap(
            reconciliationReport: report([(observation, durableID)]),
            observations: [observation]
        )

        #expect(result == NativeIdentityBootstrapResult(
            observationsProcessed: 1,
            mappingsCreated: 1,
            mappingsAlreadyPresent: 0,
            conflictsDetected: 0
        ))
        #expect(repository.nativeIdentifier(
            for: durableID,
            sourceID: sourceID
        ) == observation.nativeIdentifier)
        #expect(repository.registrationCount == 1)
    }

    @Test("An existing identical mapping is observed without registration")
    func alreadyInitializedRepository() throws {
        let sourceID = sourceID(1)
        let observation = observation(source: sourceID, provisional: 1, native: "native-1")
        let durableID = logicalID(101)
        let mapping = NativeIdentityMapping(
            logicalNodeID: durableID,
            sourceID: sourceID,
            nativeIdentifier: observation.nativeIdentifier
        )
        let repository = RecordingRepository(mappings: [mapping])

        let result = try NativeIdentityBootstrapper(repository: repository).bootstrap(
            reconciliationReport: report([(observation, durableID)]),
            observations: [observation]
        )

        #expect(result.mappingsCreated == 0)
        #expect(result.mappingsAlreadyPresent == 1)
        #expect(repository.registrationCount == 0)
    }

    @Test("Repeated bootstrap is idempotent")
    func idempotence() throws {
        let sourceID = sourceID(1)
        let observation = observation(source: sourceID, provisional: 1, native: "native-1")
        let durableID = logicalID(101)
        let repository = RecordingRepository()
        let bootstrapper = NativeIdentityBootstrapper(repository: repository)
        let reconciliation = report([(observation, durableID)])

        let first = try bootstrapper.bootstrap(
            reconciliationReport: reconciliation,
            observations: [observation]
        )
        let second = try bootstrapper.bootstrap(
            reconciliationReport: reconciliation,
            observations: [observation]
        )
        let third = try bootstrapper.bootstrap(
            reconciliationReport: reconciliation,
            observations: [observation]
        )

        #expect(first.mappingsCreated == 1)
        #expect(second == third)
        #expect(second.mappingsCreated == 0)
        #expect(second.mappingsAlreadyPresent == 1)
        #expect(repository.registrationCount == 1)
    }

    @Test("Reused reconciliation identities produce the same durable mapping")
    func reusedIdentity() throws {
        let sourceID = sourceID(1)
        let observation = observation(source: sourceID, provisional: 1, native: "native-1")
        let durableID = logicalID(101)
        let repository = RecordingRepository()

        _ = try NativeIdentityBootstrapper(repository: repository).bootstrap(
            reconciliationReport: report([(observation, durableID)], asReused: true),
            observations: [observation]
        )

        #expect(repository.nativeIdentifier(
            for: durableID,
            sourceID: sourceID
        ) == observation.nativeIdentifier)
    }

    @Test("Several hundred observations are installed without loss")
    func largeBootstrap() throws {
        let sourceID = sourceID(1)
        let pairs = (1...500).map { value in
            let observation = observation(
                source: sourceID,
                provisional: value,
                native: "native-\(value)"
            )
            return (observation, logicalID(10_000 + value))
        }
        let repository = RecordingRepository()

        let result = try NativeIdentityBootstrapper(repository: repository).bootstrap(
            reconciliationReport: report(pairs),
            observations: pairs.map(\.0)
        )

        #expect(result.observationsProcessed == 500)
        #expect(result.mappingsCreated == 500)
        #expect(repository.registrationCount == 500)
        for pair in pairs {
            #expect(repository.nativeIdentifier(
                for: pair.1,
                sourceID: sourceID
            ) == pair.0.nativeIdentifier)
        }
    }

    @Test("A durable logical identity conflict aborts before registration")
    func logicalIdentityConflict() throws {
        let sourceID = sourceID(1)
        let observation = observation(source: sourceID, provisional: 1, native: "observed")
        let durableID = logicalID(101)
        let existing = NativeIdentityMapping(
            logicalNodeID: durableID,
            sourceID: sourceID,
            nativeIdentifier: NativeNodeIdentifier("existing")
        )
        let repository = RecordingRepository(mappings: [existing])

        #expect(throws: NativeIdentityBootstrapError.durableLogicalNodeConflict(
            sourceID: sourceID,
            logicalNodeID: durableID,
            existing: existing.nativeIdentifier,
            observed: observation.nativeIdentifier
        )) {
            try NativeIdentityBootstrapper(repository: repository).bootstrap(
                reconciliationReport: report([(observation, durableID)]),
                observations: [observation]
            )
        }
        #expect(repository.registrationCount == 0)
    }

    @Test("A native identifier conflict aborts before registration")
    func nativeIdentifierConflict() throws {
        let sourceID = sourceID(1)
        let observation = observation(source: sourceID, provisional: 1, native: "shared")
        let durableID = logicalID(101)
        let existingDurableID = logicalID(202)
        let existing = NativeIdentityMapping(
            logicalNodeID: existingDurableID,
            sourceID: sourceID,
            nativeIdentifier: observation.nativeIdentifier
        )
        let repository = RecordingRepository(mappings: [existing])

        #expect(throws: NativeIdentityBootstrapError.nativeIdentifierConflict(
            sourceID: sourceID,
            nativeIdentifier: observation.nativeIdentifier,
            existing: existingDurableID,
            observed: durableID
        )) {
            try NativeIdentityBootstrapper(repository: repository).bootstrap(
                reconciliationReport: report([(observation, durableID)]),
                observations: [observation]
            )
        }
        #expect(repository.registrationCount == 0)
    }

    @Test("An observation absent from reconciliation is rejected")
    func orphanObservation() throws {
        let observation = observation(
            source: sourceID(1),
            provisional: 1,
            native: "orphan"
        )
        let repository = RecordingRepository()

        #expect(throws: NativeIdentityBootstrapError.observationWithoutDurableIdentity(
            observation
        )) {
            try NativeIdentityBootstrapper(repository: repository).bootstrap(
                reconciliationReport: report([]),
                observations: [observation]
            )
        }
        #expect(repository.registrationCount == 0)
    }

    @Test("All conflicts are validated before the first registration")
    func validationPrecedesRegistration() throws {
        let sourceID = sourceID(1)
        let valid = observation(source: sourceID, provisional: 1, native: "new")
        let conflicting = observation(source: sourceID, provisional: 2, native: "conflict")
        let existing = NativeIdentityMapping(
            logicalNodeID: logicalID(202),
            sourceID: sourceID,
            nativeIdentifier: NativeNodeIdentifier("existing")
        )
        let repository = RecordingRepository(mappings: [existing])

        #expect(throws: NativeIdentityBootstrapError.durableLogicalNodeConflict(
            sourceID: sourceID,
            logicalNodeID: existing.logicalNodeID,
            existing: existing.nativeIdentifier,
            observed: conflicting.nativeIdentifier
        )) {
            try NativeIdentityBootstrapper(repository: repository).bootstrap(
                reconciliationReport: report([
                    (valid, logicalID(101)),
                    (conflicting, existing.logicalNodeID),
                ]),
                observations: [valid, conflicting]
            )
        }
        #expect(repository.registrationCount == 0)
        #expect(repository.nativeIdentifier(
            for: logicalID(101),
            sourceID: sourceID
        ) == nil)
    }

    @Test("Registration order and statistics are deterministic")
    func determinism() throws {
        let sourceID = sourceID(1)
        let pairs = (1...20).map { value in
            let observation = observation(
                source: sourceID,
                provisional: value,
                native: "native-\(value)"
            )
            return (observation, logicalID(100 + value))
        }
        let firstRepository = RecordingRepository()
        let secondRepository = RecordingRepository()

        let first = try NativeIdentityBootstrapper(repository: firstRepository).bootstrap(
            reconciliationReport: report(pairs),
            observations: pairs.map(\.0)
        )
        let second = try NativeIdentityBootstrapper(repository: secondRepository).bootstrap(
            reconciliationReport: report(pairs),
            observations: pairs.reversed().map { $0.0 }
        )

        #expect(first == second)
        #expect(firstRepository.registrations == secondRepository.registrations)
    }

    @Test("Bootstrap never removes unrelated mappings")
    func noUnintendedRemoval() throws {
        let sourceID = sourceID(1)
        let unrelated = NativeIdentityMapping(
            logicalNodeID: logicalID(999),
            sourceID: sourceID,
            nativeIdentifier: NativeNodeIdentifier("unrelated")
        )
        let observation = observation(source: sourceID, provisional: 1, native: "new")
        let durableID = logicalID(101)
        let repository = RecordingRepository(mappings: [unrelated])

        _ = try NativeIdentityBootstrapper(repository: repository).bootstrap(
            reconciliationReport: report([(observation, durableID)]),
            observations: [observation]
        )

        #expect(repository.removalCount == 0)
        #expect(repository.nativeIdentifier(
            for: unrelated.logicalNodeID,
            sourceID: sourceID
        ) == unrelated.nativeIdentifier)
    }

    @Test("Bootstrap and its result satisfy strict concurrency contracts")
    func sendable() {
        requireSendable(NativeIdentityBootstrapper(repository: RecordingRepository()))
        requireSendable(NativeIdentityBootstrapResult(
            observationsProcessed: 0,
            mappingsCreated: 0,
            mappingsAlreadyPresent: 0,
            conflictsDetected: 0
        ))
    }

    private func report(
        _ pairs: [(NativeIdentityObservation, LogicalNodeID)],
        asReused: Bool = false
    ) -> IdentityReconciliationReport {
        let grouped = Dictionary(grouping: pairs, by: { $0.1 })
        let created = grouped.keys.sorted().map { logicalNodeID in
            CreatedIdentityReport(
                logicalNodeID: logicalNodeID,
                members: grouped[logicalNodeID, default: []].map { pair in
                    IdentityNodeReference(
                        sourceID: pair.0.sourceID,
                        provisionalLogicalID: pair.0.provisionalLogicalNodeID
                    )
                }.sorted()
            )
        }
        return IdentityReconciliationReport(
            createdIdentities: asReused ? [] : created,
            reusedIdentities: asReused ? created.map {
                ReusedIdentityReport(
                    logicalNodeID: $0.logicalNodeID,
                    members: $0.members
                )
            } : [],
            ambiguities: [],
            unresolvedObjects: [],
            diagnostics: [],
            statistics: IdentityReconciliationStatistics(
                snapshotCount: Set(pairs.map { $0.0.sourceID }).count,
                logicalSnapshotCount: Set(pairs.map { $0.0.sourceID }).count,
                groupCount: created.count,
                createdIdentityCount: asReused ? 0 : created.count,
                reusedIdentityCount: asReused ? created.count : 0,
                ambiguityCount: 0,
                unresolvedObjectCount: 0,
                baselineCommandCount: created.count
            )
        )
    }

    private func observation(
        source: BSESourceID,
        provisional: Int,
        native: String
    ) -> NativeIdentityObservation {
        NativeIdentityObservation(
            sourceID: source,
            provisionalLogicalNodeID: logicalID(provisional),
            nativeIdentifier: NativeNodeIdentifier(native)
        )
    }

    private func sourceID(_ value: Int) -> BSESourceID {
        BSESourceID(uuid(prefix: 0xA000_0000, value: value))
    }

    private func logicalID(_ value: Int) -> LogicalNodeID {
        LogicalNodeID(uuid(prefix: 0xB000_0000, value: value))
    }

    private func uuid(prefix: UInt32, value: Int) -> UUID {
        UUID(uuidString: String(
            format: "%08X-0000-0000-0000-%012llX",
            prefix,
            UInt64(value)
        ))!
    }

    private func requireSendable<T: Sendable>(_ value: T) { _ = value }
}

private nonisolated final class RecordingRepository: NativeIdentityRepository {
    private struct State: Sendable {
        let repository: InMemoryNativeIdentityRepository
        var registrations: [NativeIdentityMapping] = []
        var removals: [(LogicalNodeID, BSESourceID)] = []
    }

    private let state: Mutex<State>

    init(mappings: [NativeIdentityMapping] = []) {
        state = Mutex(State(repository: InMemoryNativeIdentityRepository(mappings: mappings)))
    }

    var registrations: [NativeIdentityMapping] {
        state.withLock { $0.registrations }
    }

    var registrationCount: Int { registrations.count }

    var removalCount: Int {
        state.withLock { $0.removals.count }
    }

    func nativeIdentifier(
        for logicalNodeID: LogicalNodeID,
        sourceID: BSESourceID
    ) -> NativeNodeIdentifier? {
        state.withLock {
            $0.repository.nativeIdentifier(for: logicalNodeID, sourceID: sourceID)
        }
    }

    func logicalNodeID(
        for nativeIdentifier: NativeNodeIdentifier,
        sourceID: BSESourceID
    ) -> LogicalNodeID? {
        state.withLock {
            $0.repository.logicalNodeID(for: nativeIdentifier, sourceID: sourceID)
        }
    }

    func register(_ mapping: NativeIdentityMapping) {
        state.withLock {
            $0.repository.register(mapping)
            $0.registrations.append(mapping)
        }
    }

    func remove(logicalNodeID: LogicalNodeID, sourceID: BSESourceID) {
        state.withLock {
            $0.repository.remove(logicalNodeID: logicalNodeID, sourceID: sourceID)
            $0.removals.append((logicalNodeID, sourceID))
        }
    }

    func applyAtomically(
        _ mutations: [NativeIdentityRepositoryMutation]
    ) throws -> NativeIdentityRepositoryMutationResult {
        try state.withLock { storage in
            let registrations: [NativeIdentityMapping] =
                mutations.compactMap { mutation in
                guard case .register(let mapping) = mutation,
                      storage.repository.nativeIdentifier(
                        for: mapping.logicalNodeID,
                        sourceID: mapping.sourceID
                      ) == nil else {
                    return nil
                }
                return mapping
            }
            let result = try storage.repository.applyAtomically(mutations)
            storage.registrations.append(contentsOf: registrations)
            return result
        }
    }
}
