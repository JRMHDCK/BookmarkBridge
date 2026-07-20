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
