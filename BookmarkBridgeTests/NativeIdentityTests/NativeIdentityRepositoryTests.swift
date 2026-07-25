//
//  NativeIdentityRepositoryTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("BSE Native Identity Resolution")
struct NativeIdentityRepositoryTests {
    @Test("A mapping can be registered and resolved")
    func registrationAndLookup() {
        let repository = InMemoryNativeIdentityRepository()
        let mapping = NativeIdentityTestSupport.mapping(
            logical: 1,
            source: 1,
            native: "native-one"
        )

        repository.register(mapping)

        #expect(repository.nativeIdentifier(
            for: mapping.logicalNodeID,
            sourceID: mapping.sourceID
        ) == mapping.nativeIdentifier)
        #expect(repository.logicalNodeID(
            for: mapping.nativeIdentifier,
            sourceID: mapping.sourceID
        ) == mapping.logicalNodeID)
    }

    @Test("Removing a mapping leaves it absent")
    func removal() {
        let mapping = NativeIdentityTestSupport.mapping(
            logical: 1,
            source: 1,
            native: "native-one"
        )
        let repository = InMemoryNativeIdentityRepository(mappings: [mapping])

        repository.remove(
            logicalNodeID: mapping.logicalNodeID,
            sourceID: mapping.sourceID
        )

        #expect(repository.nativeIdentifier(
            for: mapping.logicalNodeID,
            sourceID: mapping.sourceID
        ) == nil)
        #expect(repository.logicalNodeID(
            for: mapping.nativeIdentifier,
            sourceID: mapping.sourceID
        ) == nil)
    }

    @Test("An unknown identity returns nil")
    func absentIdentifier() {
        let repository = InMemoryNativeIdentityRepository()

        #expect(repository.nativeIdentifier(
            for: NativeIdentityTestSupport.logicalID(1),
            sourceID: NativeIdentityTestSupport.sourceID(1)
        ) == nil)
    }

    @Test("Mappings for several sources remain independent")
    func multipleSources() {
        let first = NativeIdentityTestSupport.mapping(
            logical: 1,
            source: 1,
            native: "source-one"
        )
        let second = NativeIdentityTestSupport.mapping(
            logical: 2,
            source: 2,
            native: "source-two"
        )
        let repository = InMemoryNativeIdentityRepository(mappings: [first, second])

        #expect(repository.nativeIdentifier(
            for: first.logicalNodeID,
            sourceID: first.sourceID
        ) == first.nativeIdentifier)
        #expect(repository.nativeIdentifier(
            for: second.logicalNodeID,
            sourceID: second.sourceID
        ) == second.nativeIdentifier)
    }

    @Test("One logical identity can have a different native identity per source")
    func sameLogicalIdentityAcrossSources() {
        let first = NativeIdentityTestSupport.mapping(
            logical: 1,
            source: 1,
            native: "native-a"
        )
        let second = NativeIdentityTestSupport.mapping(
            logical: 1,
            source: 2,
            native: "native-b"
        )
        let repository = InMemoryNativeIdentityRepository(mappings: [first, second])

        #expect(repository.nativeIdentifier(
            for: first.logicalNodeID,
            sourceID: first.sourceID
        ) == first.nativeIdentifier)
        #expect(repository.nativeIdentifier(
            for: second.logicalNodeID,
            sourceID: second.sourceID
        ) == second.nativeIdentifier)

        repository.remove(
            logicalNodeID: first.logicalNodeID,
            sourceID: first.sourceID
        )

        #expect(repository.nativeIdentifier(
            for: first.logicalNodeID,
            sourceID: first.sourceID
        ) == nil)
        #expect(repository.nativeIdentifier(
            for: second.logicalNodeID,
            sourceID: second.sourceID
        ) == second.nativeIdentifier)
    }

    @Test("Registering the same source key replaces only that correspondence")
    func replacement() {
        let original = NativeIdentityTestSupport.mapping(
            logical: 1,
            source: 1,
            native: "original"
        )
        let replacement = NativeIdentityTestSupport.mapping(
            logical: 1,
            source: 1,
            native: "replacement"
        )
        let repository = InMemoryNativeIdentityRepository(mappings: [original])

        repository.register(replacement)

        #expect(repository.nativeIdentifier(
            for: replacement.logicalNodeID,
            sourceID: replacement.sourceID
        ) == replacement.nativeIdentifier)
        #expect(repository.logicalNodeID(
            for: original.nativeIdentifier,
            sourceID: original.sourceID
        ) == nil)
        #expect(repository.logicalNodeID(
            for: replacement.nativeIdentifier,
            sourceID: replacement.sourceID
        ) == replacement.logicalNodeID)
    }

    @Test("Registering the same mapping again is idempotent")
    func identicalRegistration() {
        let mapping = NativeIdentityTestSupport.mapping(
            logical: 1,
            source: 1,
            native: "native-one"
        )
        let repository = InMemoryNativeIdentityRepository(mappings: [mapping])

        repository.register(mapping)
        repository.register(mapping)

        #expect(repository.nativeIdentifier(
            for: mapping.logicalNodeID,
            sourceID: mapping.sourceID
        ) == mapping.nativeIdentifier)
        #expect(repository.logicalNodeID(
            for: mapping.nativeIdentifier,
            sourceID: mapping.sourceID
        ) == mapping.logicalNodeID)
    }

    @Test("Last registration displaces a native identifier's previous logical owner")
    func nativeIdentifierReplacement() {
        let original = NativeIdentityTestSupport.mapping(
            logical: 1,
            source: 1,
            native: "shared-native"
        )
        let replacement = NativeIdentityTestSupport.mapping(
            logical: 2,
            source: 1,
            native: "shared-native"
        )
        let repository = InMemoryNativeIdentityRepository(mappings: [original])

        repository.register(replacement)

        #expect(repository.nativeIdentifier(
            for: original.logicalNodeID,
            sourceID: original.sourceID
        ) == nil)
        #expect(repository.nativeIdentifier(
            for: replacement.logicalNodeID,
            sourceID: replacement.sourceID
        ) == replacement.nativeIdentifier)
        #expect(repository.logicalNodeID(
            for: replacement.nativeIdentifier,
            sourceID: replacement.sourceID
        ) == replacement.logicalNodeID)
    }

    @Test("The same native identifier remains independent across sources")
    func inverseLookupIsSourceScoped() {
        let first = NativeIdentityTestSupport.mapping(
            logical: 1,
            source: 1,
            native: "shared-native"
        )
        let second = NativeIdentityTestSupport.mapping(
            logical: 2,
            source: 2,
            native: "shared-native"
        )
        let repository = InMemoryNativeIdentityRepository(mappings: [first, second])

        #expect(repository.logicalNodeID(
            for: first.nativeIdentifier,
            sourceID: first.sourceID
        ) == first.logicalNodeID)
        #expect(repository.logicalNodeID(
            for: second.nativeIdentifier,
            sourceID: second.sourceID
        ) == second.logicalNodeID)
    }

    @Test("Initializer conflict resolution is deterministic and coherent")
    func deterministicInitialization() {
        let first = NativeIdentityTestSupport.mapping(
            logical: 1,
            source: 1,
            native: "shared-native"
        )
        let second = NativeIdentityTestSupport.mapping(
            logical: 2,
            source: 1,
            native: "shared-native"
        )

        for _ in 0..<10 {
            let repository = InMemoryNativeIdentityRepository(mappings: [first, second])
            #expect(repository.nativeIdentifier(
                for: first.logicalNodeID,
                sourceID: first.sourceID
            ) == nil)
            #expect(repository.logicalNodeID(
                for: second.nativeIdentifier,
                sourceID: second.sourceID
            ) == second.logicalNodeID)
        }
    }

    @Test("Serializable values round-trip without interpreting native data")
    func codableRoundTrip() throws {
        let mapping = NativeIdentityTestSupport.mapping(
            logical: 1,
            source: 2,
            native: "opaque/value:42"
        )
        let data = try JSONEncoder().encode(mapping)

        #expect(try JSONDecoder().decode(
            NativeIdentityMapping.self,
            from: data
        ) == mapping)
    }

    @Test("Concurrent access is race-free and preserves independent mappings")
    func strictConcurrency() async {
        let repository = InMemoryNativeIdentityRepository()
        let mappings = (1...64).map {
            NativeIdentityTestSupport.mapping(
                logical: $0,
                source: ($0 % 4) + 1,
                native: "native-\($0)"
            )
        }

        await withTaskGroup(of: Void.self) { group in
            for mapping in mappings {
                group.addTask {
                    repository.register(mapping)
                }
            }
        }

        #expect(mappings.allSatisfy { mapping in
            repository.nativeIdentifier(
                for: mapping.logicalNodeID,
                sourceID: mapping.sourceID
            ) == mapping.nativeIdentifier
        })
        requireSendable(repository)
        requireSendable(repository as any NativeIdentityRepository)
        requireSendable(mappings[0])
    }

    @Test("A snapshot restores registrations and removals exactly")
    func snapshotRestoresMultipleChanges() throws {
        let retained = NativeIdentityTestSupport.mapping(
            logical: 1,
            source: 1,
            native: "retained"
        )
        let removed = NativeIdentityTestSupport.mapping(
            logical: 2,
            source: 1,
            native: "removed"
        )
        let added = NativeIdentityTestSupport.mapping(
            logical: 3,
            source: 1,
            native: "added"
        )
        let repository = InMemoryNativeIdentityRepository(
            mappings: [retained, removed]
        )
        let snapshot = try repository.transactionSnapshot()

        repository.remove(
            logicalNodeID: removed.logicalNodeID,
            sourceID: removed.sourceID
        )
        repository.register(added)
        try repository.restore(transactionSnapshot: snapshot)

        #expect(try repository.transactionSnapshot() == snapshot)
        #expect(repository.nativeIdentifier(
            for: removed.logicalNodeID,
            sourceID: removed.sourceID
        ) == removed.nativeIdentifier)
        #expect(repository.nativeIdentifier(
            for: added.logicalNodeID,
            sourceID: added.sourceID
        ) == nil)
    }

    @Test("Snapshot ordering and repeated restoration are deterministic")
    func snapshotRestorationIsDeterministic() throws {
        let mappings = [
            NativeIdentityTestSupport.mapping(
                logical: 3,
                source: 2,
                native: "third"
            ),
            NativeIdentityTestSupport.mapping(
                logical: 1,
                source: 1,
                native: "first"
            ),
            NativeIdentityTestSupport.mapping(
                logical: 2,
                source: 1,
                native: "second"
            ),
        ]
        let repository = InMemoryNativeIdentityRepository(mappings: mappings)
        let snapshot = try repository.transactionSnapshot()

        repository.remove(
            logicalNodeID: mappings[0].logicalNodeID,
            sourceID: mappings[0].sourceID
        )
        try repository.restore(transactionSnapshot: snapshot)
        try repository.restore(transactionSnapshot: snapshot)

        #expect(try repository.transactionSnapshot() == snapshot)
        requireSendable(snapshot)
    }

    private func requireSendable<T: Sendable>(_ value: T) { _ = value }
}

private nonisolated enum NativeIdentityTestSupport {
    static func mapping(
        logical: Int,
        source: Int,
        native: String
    ) -> NativeIdentityMapping {
        NativeIdentityMapping(
            logicalNodeID: logicalID(logical),
            sourceID: sourceID(source),
            nativeIdentifier: NativeNodeIdentifier(native)
        )
    }

    static func logicalID(_ value: Int) -> LogicalNodeID {
        LogicalNodeID(uuid(value, prefix: "10000000"))
    }

    static func sourceID(_ value: Int) -> BSESourceID {
        BSESourceID(uuid(value, prefix: "20000000"))
    }

    private static func uuid(_ value: Int, prefix: String) -> UUID {
        UUID(uuidString: String(
            format: "\(prefix)-0000-0000-0000-%012d",
            value
        ))!
    }
}
