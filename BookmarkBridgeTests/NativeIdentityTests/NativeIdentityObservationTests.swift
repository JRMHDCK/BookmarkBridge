//
//  NativeIdentityObservationTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("BSE Native Identity Observation")
struct NativeIdentityObservationTests {
    @Test("Observation preserves its three generic identity values")
    func valuesAndEquality() {
        let sourceID = BSESourceID(UUID(uuidString: "91000000-0000-0000-0000-000000000001")!)
        let logicalNodeID = LogicalNodeID(
            UUID(uuidString: "92000000-0000-0000-0000-000000000001")!
        )
        let nativeIdentifier = NativeNodeIdentifier("opaque-native-identity")
        let first = NativeIdentityObservation(
            sourceID: sourceID,
            provisionalLogicalNodeID: logicalNodeID,
            nativeIdentifier: nativeIdentifier
        )
        let second = NativeIdentityObservation(
            sourceID: sourceID,
            provisionalLogicalNodeID: logicalNodeID,
            nativeIdentifier: nativeIdentifier
        )

        #expect(first == second)
        #expect(first.sourceID == sourceID)
        #expect(first.provisionalLogicalNodeID == logicalNodeID)
        #expect(first.nativeIdentifier == nativeIdentifier)
        requireSendable(first)
    }

    @Test("Chrome observation preserves preferred identity and continuity proof")
    func chromeMigrationEvidence() {
        let observation = NativeIdentityObservation(
            sourceID: BSESourceID(UUID(
                uuidString: "91000000-0000-0000-0000-000000000002"
            )!),
            provisionalLogicalNodeID: LogicalNodeID(UUID(
                uuidString: "92000000-0000-0000-0000-000000000002"
            )!),
            nativeIdentifier: NativeNodeIdentifier("guid:abc"),
            nativeIdentityKind: .chromeGUID,
            continuityIdentifier: NativeNodeIdentifier("id:42"),
            continuityIdentityKind: .chromeIDFallback
        )

        #expect(observation.nativeIdentityKind == .chromeGUID)
        #expect(
            observation.continuityIdentifier
                == NativeNodeIdentifier("id:42")
        )
        #expect(
            observation.continuityIdentityKind == .chromeIDFallback
        )
        requireSendable(observation)
    }

    private func requireSendable<T: Sendable>(_ value: T) { _ = value }
}
