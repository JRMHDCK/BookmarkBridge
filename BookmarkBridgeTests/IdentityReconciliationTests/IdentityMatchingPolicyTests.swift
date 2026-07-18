//
//  IdentityMatchingPolicyTests.swift
//  BookmarkBridgeTests
//

import Testing
@testable import BookmarkBridge

@Suite("BSE Identity Matching Policy")
struct IdentityMatchingPolicyTests {
    private let policy = StrictIdentityMatchingPolicy()

    @Test("Baseline observation reuses its durable identity")
    func reuseFromBaseline() throws {
        let sourceID = try ReconciliationTestSupport.sourceID(1)
        let provisionalID = try ReconciliationTestSupport.provisionalID(1)
        let durableID = try ReconciliationTestSupport.durableID(1)
        let baseline = try ReconciliationTestSupport.baseline(records: [
            ReconciliationTestSupport.record(
                id: durableID,
                observations: [ReconciliationTestSupport.observation(
                    source: sourceID,
                    provisional: provisionalID
                )]
            ),
        ])
        let group = ReconciliationTestSupport.group(
            members: [(sourceID, provisionalID)],
            result: .noMatch(reason: .noCandidates)
        )

        let decision = try policy.decide(for: IdentityMatchingContext(
            baseline: baseline,
            group: group
        ))

        #expect(decision == .reuse(durableID))
    }

    @Test("No Baseline identity and no match requests creation")
    func createForUnmatchedObject() throws {
        let sourceID = try ReconciliationTestSupport.sourceID(1)
        let provisionalID = try ReconciliationTestSupport.provisionalID(1)
        let group = ReconciliationTestSupport.group(
            members: [(sourceID, provisionalID)],
            result: .noMatch(reason: .noCandidates)
        )

        let decision = try policy.decide(for: IdentityMatchingContext(
            baseline: ReconciliationTestSupport.emptyBaseline(),
            group: group
        ))

        #expect(decision == .create)
    }

    @Test("Matching Engine ambiguity is preserved without selection")
    func preservesAmbiguity() throws {
        let sourceID = try ReconciliationTestSupport.sourceID(1)
        let provisionalID = try ReconciliationTestSupport.provisionalID(1)
        let candidates = [
            try ReconciliationTestSupport.durableID(2),
            try ReconciliationTestSupport.durableID(1),
        ]
        let group = ReconciliationTestSupport.group(
            members: [(sourceID, provisionalID)],
            result: .ambiguous(
                candidateIDs: candidates,
                reason: .ambiguousCandidates(count: 2)
            )
        )

        let decision = try policy.decide(for: IdentityMatchingContext(
            baseline: ReconciliationTestSupport.emptyBaseline(),
            group: group
        ))

        #expect(decision == .ambiguous(candidateIDs: candidates.sorted()))
    }

    @Test("Contradictory Baseline observations become ambiguous")
    func ambiguousBaselineCandidates() throws {
        let sourceID = try ReconciliationTestSupport.sourceID(1)
        let provisionalID = try ReconciliationTestSupport.provisionalID(1)
        let firstID = try ReconciliationTestSupport.durableID(1)
        let secondID = try ReconciliationTestSupport.durableID(2)
        let observation = try ReconciliationTestSupport.observation(
            source: sourceID,
            provisional: provisionalID
        )
        let baseline = try ReconciliationTestSupport.baseline(records: [
            ReconciliationTestSupport.record(id: secondID, observations: [observation]),
            ReconciliationTestSupport.record(id: firstID, observations: [observation]),
        ])
        let group = ReconciliationTestSupport.group(
            members: [(sourceID, provisionalID)],
            result: .noMatch(reason: .noCandidates)
        )

        let decision = try policy.decide(for: IdentityMatchingContext(
            baseline: baseline,
            group: group
        ))

        #expect(decision == .ambiguous(candidateIDs: [firstID, secondID]))
    }

    @Test("A match pointing outside its supplied group is not trusted")
    func rejectsCandidateOutsideGroup() throws {
        let sourceID = try ReconciliationTestSupport.sourceID(1)
        let provisionalID = try ReconciliationTestSupport.provisionalID(1)
        let outsideID = try ReconciliationTestSupport.provisionalID(2)
        let group = ReconciliationTestSupport.group(
            members: [(sourceID, provisionalID)],
            result: .match(candidateID: outsideID, reason: .sameBookmarkURL)
        )

        let decision = try policy.decide(for: IdentityMatchingContext(
            baseline: ReconciliationTestSupport.emptyBaseline(),
            group: group
        ))

        #expect(decision == .ambiguous(candidateIDs: [outsideID]))
    }
}
