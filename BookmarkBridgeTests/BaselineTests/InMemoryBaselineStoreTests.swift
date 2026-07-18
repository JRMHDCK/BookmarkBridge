//
//  InMemoryBaselineStoreTests.swift
//  BookmarkBridgeTests
//

import Testing
@testable import BookmarkBridge

@Suite("BSE In-Memory Baseline Store")
struct InMemoryBaselineStoreTests {
    @Test("Empty store loads nil")
    func emptyStore() async throws {
        let store = InMemoryBaselineStore()

        #expect(try await store.load() == nil)
    }

    @Test("Creates and loads an immutable baseline value")
    func createAndLoad() async throws {
        let store = InMemoryBaselineStore()
        let baseline = try BaselineTestSupport.emptyBaseline()

        try await store.save(baseline, expectedRevision: nil)

        #expect(try await store.load() == baseline)
    }

    @Test("Conditional save accepts the matching revision")
    func matchingRevision() async throws {
        let original = try BaselineTestSupport.emptyBaseline()
        let store = InMemoryBaselineStore(baseline: original)
        let updated = try BaselineEngine().apply(
            commands: [.createIdentity(CreateIdentityCommand(
                logicalNodeID: BaselineTestSupport.logicalID(1),
                observations: []
            ))],
            to: original
        ).baseline

        try await store.save(updated, expectedRevision: .zero)

        #expect(try await store.load() == updated)
    }

    @Test("Conditional save rejects a stale revision without mutation")
    func staleRevision() async throws {
        let original = try BaselineTestSupport.emptyBaseline()
        let updated = try BaselineEngine().apply(
            commands: [.createIdentity(CreateIdentityCommand(
                logicalNodeID: BaselineTestSupport.logicalID(1),
                observations: []
            ))],
            to: original
        ).baseline
        let store = InMemoryBaselineStore(baseline: updated)

        await #expect(throws: BaselineError.revisionConflict(
            expected: .zero,
            actual: updated.revision
        )) {
            try await store.save(updated, expectedRevision: .zero)
        }
        #expect(try await store.load() == updated)
    }

    @Test("Store prevents changing BaselineID")
    func immutableBaselineID() async throws {
        let original = try BaselineTestSupport.emptyBaseline()
        let different = try Baseline(
            baselineID: BaselineTestSupport.baselineID(2),
            schemaVersion: .current,
            revision: BaselineRevision(1),
            identityRecords: []
        )
        let store = InMemoryBaselineStore(baseline: original)

        await #expect(throws: BaselineError.invariantViolation(.baselineIDChanged)) {
            try await store.save(different, expectedRevision: .zero)
        }
        #expect(try await store.load() == original)
    }

    @Test("Store rejects a non-monotone replacement")
    func nonMonotoneRevision() async throws {
        let baseline = try BaselineTestSupport.emptyBaseline()
        let store = InMemoryBaselineStore(baseline: baseline)

        await #expect(throws: BaselineError.invariantViolation(.nonMonotoneRevision)) {
            try await store.save(baseline, expectedRevision: .zero)
        }
    }

    @Test("Concurrent compare-and-save permits exactly one winner")
    func concurrentTransactions() async throws {
        let original = try BaselineTestSupport.emptyBaseline()
        let store = InMemoryBaselineStore(baseline: original)
        let first = try BaselineEngine().apply(
            commands: [.createIdentity(CreateIdentityCommand(
                logicalNodeID: BaselineTestSupport.logicalID(1),
                observations: []
            ))],
            to: original
        ).baseline
        let second = try BaselineEngine().apply(
            commands: [.createIdentity(CreateIdentityCommand(
                logicalNodeID: BaselineTestSupport.logicalID(2),
                observations: []
            ))],
            to: original
        ).baseline

        let successes = await withTaskGroup(of: Bool.self) { group in
            for candidate in [first, second] {
                group.addTask {
                    do {
                        try await store.save(candidate, expectedRevision: .zero)
                        return true
                    } catch {
                        return false
                    }
                }
            }
            var values: [Bool] = []
            for await value in group { values.append(value) }
            return values
        }

        #expect(successes.filter { $0 }.count == 1)
        #expect(try await store.load()?.revision == BaselineRevision(1))
    }
}
