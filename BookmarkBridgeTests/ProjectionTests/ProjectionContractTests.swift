//
//  ProjectionContractTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("BSE Projection Contract")
struct ProjectionContractTests {
    @Test("One-way direction preserves distinct source and target identities")
    func direction() {
        let direction = SynchronizationDirection.oneWay(
            source: sourceID(1),
            target: sourceID(2)
        )

        #expect(direction.source == sourceID(1))
        #expect(direction.target == sourceID(2))
        #expect(direction.source != direction.target)
    }

    @Test("SynchronizationDirection is Hashable and Sendable")
    func directionValueSemantics() {
        let direction = SynchronizationDirection.oneWay(
            source: sourceID(1),
            target: sourceID(2)
        )
        let values: Set<SynchronizationDirection> = [direction, direction]

        #expect(values == [direction])
        requireSendable(direction)
    }

    @Test("ProjectionRequest preserves explicit source authority and target state")
    func validRequest() throws {
        let direction = SynchronizationDirection.oneWay(
            source: sourceID(1),
            target: sourceID(2)
        )
        let source = try snapshot(source: sourceID(1), capturedAt: 200)
        let target = try snapshot(source: sourceID(2), capturedAt: 100)
        let policy = SynchronizationPolicy.allChanges(direction: direction)

        let request = try ProjectionRequest(
            sourceSnapshot: source,
            targetSnapshot: target,
            policy: policy
        )

        #expect(request.sourceSnapshot == source)
        #expect(request.targetSnapshot == target)
        #expect(request.policy == policy)
        requireSendable(request)
    }

    @Test("Inverted source and target snapshots are rejected")
    func invertedSnapshots() throws {
        let direction = SynchronizationDirection.oneWay(
            source: sourceID(1),
            target: sourceID(2)
        )
        let source = try snapshot(source: sourceID(2))
        let target = try snapshot(source: sourceID(1))

        #expect(throws: ProjectionValidationError.sourceSnapshotMismatch(
            expected: sourceID(1),
            actual: sourceID(2)
        )) {
            try ProjectionRequest(
                sourceSnapshot: source,
                targetSnapshot: target,
                policy: .allChanges(direction: direction)
            )
        }
    }

    @Test("A mismatched target snapshot is rejected explicitly")
    func targetMismatch() throws {
        let direction = SynchronizationDirection.oneWay(
            source: sourceID(1),
            target: sourceID(2)
        )
        let source = try snapshot(source: sourceID(1))
        let target = try snapshot(source: sourceID(3))

        #expect(throws: ProjectionValidationError.targetSnapshotMismatch(
            expected: sourceID(2),
            actual: sourceID(3)
        )) {
            try ProjectionRequest(
                sourceSnapshot: source,
                targetSnapshot: target,
                policy: .allChanges(direction: direction)
            )
        }
    }

    @Test("A direction using the same source twice is rejected")
    func identicalSourceAndTarget() throws {
        let sameSource = sourceID(1)
        let direction = SynchronizationDirection.oneWay(
            source: sameSource,
            target: sameSource
        )
        let snapshot = try snapshot(source: sameSource)

        #expect(throws: ProjectionValidationError.identicalSourceAndTarget(
            sameSource
        )) {
            try ProjectionRequest(
                sourceSnapshot: snapshot,
                targetSnapshot: snapshot,
                policy: .allChanges(direction: direction)
            )
        }
    }

    @Test("SynchronizationPolicy preserves every independent decision")
    func policy() {
        let direction = SynchronizationDirection.oneWay(
            source: sourceID(1),
            target: sourceID(2)
        )
        let policy = SynchronizationPolicy(
            direction: direction,
            changeSelection: .contentOnly,
            deletedLifecycleHandling: .archive
        )

        #expect(policy.direction == direction)
        #expect(policy.changeSelection == .contentOnly)
        #expect(policy.deletedLifecycleHandling == .archive)
        requireSendable(policy)
    }

    private func snapshot(
        source: BSESourceID,
        capturedAt: TimeInterval = 0
    ) throws -> LogicalSnapshot {
        LogicalSnapshot(
            source: source,
            capturedAt: Date(timeIntervalSince1970: capturedAt),
            tree: try BSETree(nodes: [])
        )
    }

    private func sourceID(_ value: Int) -> BSESourceID {
        BSESourceID(UUID(uuidString: String(
            format: "C0000000-0000-0000-0000-%012d",
            value
        ))!)
    }

    private func requireSendable<T: Sendable>(_ value: T) { _ = value }
}
