//
//  NativeIdentityResolverTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Synchronization
import Testing
@testable import BookmarkBridge

@Suite("BSE-799 Native Identity Resolution")
struct NativeIdentityResolverTests {
    @Test("Known native identities restore their durable logical identities")
    func resolvesKnownIdentity() throws {
        let sourceID = resolutionSourceID(1)
        let provisionalRootID = resolutionLogicalID(1)
        let provisionalBookmarkID = resolutionLogicalID(2)
        let durableRootID = resolutionLogicalID(101)
        let nativeRootID = NativeNodeIdentifier("native-root")
        let nativeBookmarkID = NativeNodeIdentifier("native-bookmark")
        let repository = ResolutionRepositorySpy(mappings: [
            NativeIdentityMapping(
                logicalNodeID: durableRootID,
                sourceID: sourceID,
                nativeIdentifier: nativeRootID
            ),
        ])
        let input = try resolutionReadResult(
            sourceID: sourceID,
            nodes: [
                try BSENode(
                    logicalID: provisionalRootID,
                    kind: .folder,
                    title: "Root",
                    position: 0
                ),
                try BSENode(
                    logicalID: provisionalBookmarkID,
                    kind: .bookmark,
                    title: "Bookmark",
                    parentID: provisionalRootID,
                    position: 0,
                    url: URL(string: "https://example.com")
                ),
            ],
            nativeIdentifiers: [nativeRootID, nativeBookmarkID]
        )

        let result = try NativeIdentityResolver(repository: repository)
            .resolve(input)

        #expect(result.resolvedIdentityCount == 1)
        #expect(result.unresolvedIdentityCount == 1)
        #expect(result.readResult.snapshot.tree.nodes.map(\.logicalID) == [
            durableRootID,
            provisionalBookmarkID,
        ])
        #expect(
            result.readResult.snapshot.tree.node(
                for: provisionalBookmarkID
            )?.parentID == durableRootID
        )
        #expect(
            result.readResult.nativeIdentityObservations
                .map(\.provisionalLogicalNodeID) == [
                    durableRootID,
                    provisionalBookmarkID,
                ]
        )
        #expect(repository.mutationInvocationCount == 0)
        #expect(
            repository.logicalNodeID(
                for: nativeBookmarkID,
                sourceID: sourceID
            ) == nil
        )
    }

    @Test("Unknown native identities keep their provisional identities")
    func leavesUnknownIdentityUnchanged() throws {
        let sourceID = resolutionSourceID(1)
        let provisionalID = resolutionLogicalID(1)
        let input = try resolutionReadResult(
            sourceID: sourceID,
            nodes: [
                try BSENode(
                    logicalID: provisionalID,
                    kind: .folder,
                    title: "Root",
                    position: 0
                ),
            ],
            nativeIdentifiers: [NativeNodeIdentifier("unknown")]
        )
        let repository = ResolutionRepositorySpy()

        let result = try NativeIdentityResolver(repository: repository)
            .resolve(input)

        #expect(result.readResult == input)
        #expect(result.resolvedIdentityCount == 0)
        #expect(result.unresolvedIdentityCount == 1)
        #expect(repository.mutationInvocationCount == 0)
    }

    @Test("Continuity evidence resolves a migrated Chrome observation")
    func resolvesContinuityIdentity() throws {
        let sourceID = resolutionSourceID(2)
        let provisionalID = resolutionLogicalID(1)
        let durableID = resolutionLogicalID(101)
        let fallback = NativeNodeIdentifier("id:42")
        let repository = ResolutionRepositorySpy(mappings: [
            NativeIdentityMapping(
                logicalNodeID: durableID,
                sourceID: sourceID,
                nativeIdentifier: fallback
            ),
        ])
        let snapshot = BSESnapshot(
            source: sourceID,
            capturedAt: Date(timeIntervalSince1970: 1),
            tree: try BSETree(nodes: [
                try BSENode(
                    logicalID: provisionalID,
                    kind: .folder,
                    title: "Root",
                    position: 0
                ),
            ])
        )
        let input = EndToEndSynchronizationReadResult(
            snapshot: snapshot,
            nativeIdentityObservations: [
                NativeIdentityObservation(
                    sourceID: sourceID,
                    provisionalLogicalNodeID: provisionalID,
                    nativeIdentifier: NativeNodeIdentifier("guid:abc"),
                    nativeIdentityKind: .chromeGUID,
                    continuityIdentifier: fallback,
                    continuityIdentityKind: .chromeIDFallback
                ),
            ]
        )

        let result = try NativeIdentityResolver(repository: repository)
            .resolve(input)

        #expect(
            result.readResult.snapshot.tree.nodes.first?.logicalID == durableID
        )
        #expect(repository.mutationInvocationCount == 0)
    }

    @Test("Resolution is deterministic and Sendable")
    func deterministicAndSendable() async throws {
        let sourceID = resolutionSourceID(1)
        let provisionalID = resolutionLogicalID(1)
        let durableID = resolutionLogicalID(101)
        let nativeID = NativeNodeIdentifier("native-root")
        let repository = ResolutionRepositorySpy(mappings: [
            NativeIdentityMapping(
                logicalNodeID: durableID,
                sourceID: sourceID,
                nativeIdentifier: nativeID
            ),
        ])
        let input = try resolutionReadResult(
            sourceID: sourceID,
            nodes: [
                try BSENode(
                    logicalID: provisionalID,
                    kind: .folder,
                    title: "Root",
                    position: 0
                ),
            ],
            nativeIdentifiers: [nativeID]
        )
        let resolver = NativeIdentityResolver(repository: repository)

        let first = try await Task.detached {
            try resolver.resolve(input)
        }.value
        let second = try resolver.resolve(input)

        #expect(first == second)
        requireResolutionSendable(resolver)
        requireResolutionSendable(first)
        #expect(repository.mutationInvocationCount == 0)
    }
}

private final class ResolutionRepositorySpy: NativeIdentityRepository {
    private struct State: Sendable {
        var nativeByLogical: [ResolutionLogicalKey: NativeNodeIdentifier] = [:]
        var logicalByNative: [ResolutionNativeKey: LogicalNodeID] = [:]
        var mutationInvocationCount = 0
    }

    private let state: Mutex<State>

    init(mappings: [NativeIdentityMapping] = []) {
        var initial = State()
        for mapping in mappings {
            initial.nativeByLogical[ResolutionLogicalKey(
                logicalNodeID: mapping.logicalNodeID,
                sourceID: mapping.sourceID
            )] = mapping.nativeIdentifier
            initial.logicalByNative[ResolutionNativeKey(
                nativeIdentifier: mapping.nativeIdentifier,
                sourceID: mapping.sourceID
            )] = mapping.logicalNodeID
        }
        state = Mutex(initial)
    }

    var mutationInvocationCount: Int {
        state.withLock(\.mutationInvocationCount)
    }

    func nativeIdentifier(
        for logicalNodeID: LogicalNodeID,
        sourceID: BSESourceID
    ) -> NativeNodeIdentifier? {
        state.withLock {
            $0.nativeByLogical[ResolutionLogicalKey(
                logicalNodeID: logicalNodeID,
                sourceID: sourceID
            )]
        }
    }

    func logicalNodeID(
        for nativeIdentifier: NativeNodeIdentifier,
        sourceID: BSESourceID
    ) -> LogicalNodeID? {
        state.withLock {
            $0.logicalByNative[ResolutionNativeKey(
                nativeIdentifier: nativeIdentifier,
                sourceID: sourceID
            )]
        }
    }

    func register(_ mapping: NativeIdentityMapping) {
        state.withLock { $0.mutationInvocationCount += 1 }
    }

    func remove(
        logicalNodeID: LogicalNodeID,
        sourceID: BSESourceID
    ) {
        state.withLock { $0.mutationInvocationCount += 1 }
    }

    func applyAtomically(
        _ mutations: [NativeIdentityRepositoryMutation]
    ) throws -> NativeIdentityRepositoryMutationResult {
        state.withLock { $0.mutationInvocationCount += 1 }
        return NativeIdentityRepositoryMutationResult(
            registrationsApplied: 0,
            registrationsAlreadyPresent: 0,
            migrationsApplied: 0
        )
    }
}

private struct ResolutionLogicalKey: Hashable, Sendable {
    let logicalNodeID: LogicalNodeID
    let sourceID: BSESourceID
}

private struct ResolutionNativeKey: Hashable, Sendable {
    let nativeIdentifier: NativeNodeIdentifier
    let sourceID: BSESourceID
}

private func resolutionReadResult(
    sourceID: BSESourceID,
    nodes: [BSENode],
    nativeIdentifiers: [NativeNodeIdentifier]
) throws -> EndToEndSynchronizationReadResult {
    #expect(nodes.count == nativeIdentifiers.count)
    return EndToEndSynchronizationReadResult(
        snapshot: BSESnapshot(
            source: sourceID,
            capturedAt: Date(timeIntervalSince1970: 1),
            tree: try BSETree(nodes: nodes)
        ),
        nativeIdentityObservations: zip(nodes, nativeIdentifiers).map {
            NativeIdentityObservation(
                sourceID: sourceID,
                provisionalLogicalNodeID: $0.logicalID,
                nativeIdentifier: $1
            )
        }
    )
}

private func resolutionSourceID(_ value: Int) -> BSESourceID {
    BSESourceID(resolutionUUID(value))
}

private func resolutionLogicalID(_ value: Int) -> LogicalNodeID {
    LogicalNodeID(resolutionUUID(value))
}

private func resolutionUUID(_ value: Int) -> UUID {
    let high = UInt8(truncatingIfNeeded: value >> 8)
    let low = UInt8(truncatingIfNeeded: value)
    return UUID(uuid: (
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, high, low
    ))
}

private func requireResolutionSendable<T: Sendable>(_: T) {}
