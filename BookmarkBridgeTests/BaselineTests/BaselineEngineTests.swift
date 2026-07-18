//
//  BaselineEngineTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("BSE Baseline Engine")
struct BaselineEngineTests {
    private let engine = BaselineEngine()

    @Test("Creates an immutable empty baseline")
    func emptyBaseline() throws {
        let baseline = try BaselineTestSupport.emptyBaseline()

        #expect(baseline.revision == .zero)
        #expect(baseline.schemaVersion == .current)
        #expect(baseline.identityRecords.isEmpty)
        #expect(baseline.metadata.migrationHistory.isEmpty)
    }

    @Test("Creates one durable identity")
    func createIdentity() throws {
        let baseline = try BaselineTestSupport.emptyBaseline()
        let logicalID = try BaselineTestSupport.logicalID(1)
        let observation = try BaselineTestSupport.observation(source: 1)

        let changeSet = try engine.apply(
            commands: [.createIdentity(CreateIdentityCommand(
                logicalNodeID: logicalID,
                observations: [observation]
            ))],
            to: baseline
        )

        let record = try #require(changeSet.baseline.identity(logicalID))
        #expect(record.revision.rawValue == 1)
        #expect(record.state == .active)
        #expect(record.observations == [observation])
        #expect(changeSet.createdIdentities == [logicalID])
        #expect(changeSet.modifiedIdentities.isEmpty)
        #expect(changeSet.revisionBefore == .zero)
        #expect(changeSet.revisionAfter == BaselineRevision(1))
        #expect(baseline.identityRecords.isEmpty)
    }

    @Test("Never recycles an existing logical identity")
    func duplicateIdentity() throws {
        let logicalID = try BaselineTestSupport.logicalID(1)
        let created = try BaselineTestSupport.baselineWithIdentity(logicalID: logicalID)

        #expect(throws: BaselineError.identityAlreadyExists(logicalID)) {
            _ = try engine.apply(
                commands: [.createIdentity(CreateIdentityCommand(
                    logicalNodeID: logicalID,
                    observations: []
                ))],
                to: created
            )
        }
    }

    @Test("Update observation adds a source then replaces only that source")
    func updateAndReplaceObservation() throws {
        let logicalID = try BaselineTestSupport.logicalID(1)
        let original = try BaselineTestSupport.baselineWithIdentity(
            logicalID: logicalID,
            observations: [BaselineTestSupport.observation(source: 1)]
        )
        let secondSource = try BaselineTestSupport.observation(source: 2)
        let added = try engine.apply(
            commands: [.updateObservation(UpdateObservationCommand(
                logicalNodeID: logicalID,
                expectedIdentityRevision: IdentityRevision(1),
                observation: secondSource
            ))],
            to: original
        ).baseline
        let replacement = try BaselineTestSupport.observation(
            source: 2,
            provisional: 22,
            lastObservedAt: BaselineTestSupport.date(20),
            presence: .absent
        )

        let replaced = try engine.apply(
            commands: [.updateObservation(UpdateObservationCommand(
                logicalNodeID: logicalID,
                expectedIdentityRevision: IdentityRevision(2),
                observation: replacement
            ))],
            to: added
        ).baseline

        let record = try #require(replaced.identity(logicalID))
        #expect(record.observations.count == 2)
        #expect(record.observations.first { $0.sourceID == replacement.sourceID } == replacement)
        #expect(record.revision.rawValue == 3)
        #expect(replaced.revision.rawValue == 3)
    }

    @Test("Multiple sources remain distinct observations")
    func multipleSources() throws {
        let logicalID = try BaselineTestSupport.logicalID(1)
        let first = try BaselineTestSupport.observation(source: 1)
        let second = try BaselineTestSupport.observation(source: 2)
        let baseline = try BaselineTestSupport.baselineWithIdentity(
            logicalID: logicalID,
            observations: [second, first]
        )

        let observations = try #require(baseline.identity(logicalID)).observations

        #expect(observations.map(\.sourceID) == [first.sourceID, second.sourceID])
    }

    @Test("Replaces opaque recognition artifacts without interpreting them")
    func replaceRecognitionArtifacts() throws {
        let logicalID = try BaselineTestSupport.logicalID(1)
        let sourceID = try BaselineTestSupport.sourceID(1)
        let baseline = try BaselineTestSupport.baselineWithIdentity(logicalID: logicalID)
        let replacement = [try BaselineTestSupport.artifact("future.family", version: 9, bytes: [9, 8])]

        let changed = try engine.apply(
            commands: [.replaceRecognitionArtifacts(ReplaceRecognitionArtifactsCommand(
                logicalNodeID: logicalID,
                expectedIdentityRevision: IdentityRevision(1),
                sourceID: sourceID,
                recognitionArtifacts: replacement
            ))],
            to: baseline
        )

        let observation = try #require(changed.baseline.identity(logicalID)?.observations.first)
        #expect(observation.recognitionArtifacts == replacement)
        #expect(changed.modifiedIdentities == [logicalID])
    }

    @Test("Archives, logically deletes, then reactivates an identity")
    func lifecycle() throws {
        let logicalID = try BaselineTestSupport.logicalID(1)
        let baseline = try BaselineTestSupport.baselineWithIdentity(logicalID: logicalID)
        let commands: [BaselineCommand] = [
            .archiveIdentity(ArchiveIdentityCommand(
                logicalNodeID: logicalID,
                expectedIdentityRevision: try IdentityRevision(1)
            )),
            .markIdentityDeleted(MarkIdentityDeletedCommand(
                logicalNodeID: logicalID,
                expectedIdentityRevision: try IdentityRevision(2)
            )),
            .reactivateIdentity(ReactivateIdentityCommand(
                logicalNodeID: logicalID,
                expectedIdentityRevision: try IdentityRevision(3)
            )),
        ]

        let result = try engine.apply(commands: commands, to: baseline)
        let record = try #require(result.baseline.identity(logicalID))

        #expect(record.state == .active)
        #expect(record.revision.rawValue == 4)
        #expect(result.baseline.revision.rawValue == 4)
        #expect(result.modifiedIdentities == [logicalID])
        #expect(result.executedCommands == commands)
    }

    @Test("Rejects an invalid lifecycle transition")
    func invalidLifecycleTransition() throws {
        let logicalID = try BaselineTestSupport.logicalID(1)
        let baseline = try BaselineTestSupport.baselineWithIdentity(logicalID: logicalID)

        #expect(throws: BaselineError.invalidLifecycleTransition(
            logicalNodeID: logicalID,
            from: .active,
            to: .active
        )) {
            _ = try engine.apply(
                commands: [.reactivateIdentity(ReactivateIdentityCommand(
                    logicalNodeID: logicalID,
                    expectedIdentityRevision: IdentityRevision(1)
                ))],
                to: baseline
            )
        }
    }

    @Test("Global and identity revisions increase monotonically per command")
    func monotoneRevisions() throws {
        let baseline = try BaselineTestSupport.emptyBaseline()
        let firstID = try BaselineTestSupport.logicalID(1)
        let secondID = try BaselineTestSupport.logicalID(2)

        let result = try engine.apply(commands: [
            .createIdentity(CreateIdentityCommand(logicalNodeID: firstID, observations: [])),
            .createIdentity(CreateIdentityCommand(logicalNodeID: secondID, observations: [])),
            .archiveIdentity(ArchiveIdentityCommand(
                logicalNodeID: firstID,
                expectedIdentityRevision: try IdentityRevision(1)
            )),
        ], to: baseline)

        #expect(result.revisionAfter.rawValue == 3)
        #expect(result.baseline.identity(firstID)?.revision.rawValue == 2)
        #expect(result.baseline.identity(secondID)?.revision.rawValue == 1)
    }

    @Test("Rejects a stale identity revision")
    func identityRevisionConflict() throws {
        let logicalID = try BaselineTestSupport.logicalID(1)
        let baseline = try BaselineTestSupport.baselineWithIdentity(logicalID: logicalID)
        let stale = try IdentityRevision(2)

        #expect(throws: BaselineError.identityRevisionConflict(
            logicalNodeID: logicalID,
            expected: stale,
            actual: try IdentityRevision(1)
        )) {
            _ = try engine.apply(
                commands: [.archiveIdentity(ArchiveIdentityCommand(
                    logicalNodeID: logicalID,
                    expectedIdentityRevision: stale
                ))],
                to: baseline
            )
        }
    }

    @Test("Reports a missing observation")
    func observationNotFound() throws {
        let logicalID = try BaselineTestSupport.logicalID(1)
        let missingSource = try BaselineTestSupport.sourceID(2)
        let baseline = try BaselineTestSupport.baselineWithIdentity(logicalID: logicalID)

        #expect(throws: BaselineError.observationNotFound(
            logicalNodeID: logicalID,
            sourceID: missingSource
        )) {
            _ = try engine.apply(
                commands: [.replaceRecognitionArtifacts(ReplaceRecognitionArtifactsCommand(
                    logicalNodeID: logicalID,
                    expectedIdentityRevision: IdentityRevision(1),
                    sourceID: missingSource,
                    recognitionArtifacts: []
                ))],
                to: baseline
            )
        }
    }

    @Test("Rejects duplicate observations in identity creation")
    func duplicateObservation() throws {
        let logicalID = try BaselineTestSupport.logicalID(1)
        let observation = try BaselineTestSupport.observation(source: 1)
        let baseline = try BaselineTestSupport.emptyBaseline()

        #expect(throws: BaselineError.duplicateObservation(
            logicalNodeID: logicalID,
            sourceID: observation.sourceID
        )) {
            _ = try engine.apply(
                commands: [.createIdentity(CreateIdentityCommand(
                    logicalNodeID: logicalID,
                    observations: [observation, observation]
                ))],
                to: baseline
            )
        }
    }

    @Test("Model constructors enforce baseline invariants")
    func invariantViolation() throws {
        let logicalID = try BaselineTestSupport.logicalID(1)
        let record = try BaselineTestSupport.identityRecord(logicalID: logicalID)

        #expect(throws: BaselineError.invariantViolation(.duplicateLogicalNodeID)) {
            _ = try Baseline(
                baselineID: BaselineTestSupport.baselineID(),
                schemaVersion: .current,
                revision: BaselineRevision(1),
                identityRecords: [record, record]
            )
        }
    }

    @Test("A failed batch leaves its immutable input unchanged")
    func atomicBatchRollback() throws {
        let baseline = try BaselineTestSupport.emptyBaseline()
        let logicalID = try BaselineTestSupport.logicalID(1)
        let commands: [BaselineCommand] = [
            .createIdentity(CreateIdentityCommand(logicalNodeID: logicalID, observations: [])),
            .createIdentity(CreateIdentityCommand(logicalNodeID: logicalID, observations: [])),
        ]

        #expect(throws: BaselineError.identityAlreadyExists(logicalID)) {
            _ = try engine.apply(commands: commands, to: baseline)
        }
        #expect(baseline.revision == .zero)
        #expect(baseline.identityRecords.isEmpty)
    }

    @Test("Same baseline and commands produce exactly the same change set")
    func deterministic() throws {
        let baseline = try BaselineTestSupport.emptyBaseline()
        let command = BaselineCommand.createIdentity(CreateIdentityCommand(
            logicalNodeID: try BaselineTestSupport.logicalID(1),
            observations: [try BaselineTestSupport.observation(source: 1)]
        ))

        let first = try engine.apply(commands: [command], to: baseline)
        let second = try engine.apply(commands: [command], to: baseline)

        #expect(first == second)
    }

    @Test("Baseline values satisfy strict Sendable boundaries")
    func strictConcurrency() throws {
        let baseline = try BaselineTestSupport.emptyBaseline()
        let command = BaselineCommand.createIdentity(CreateIdentityCommand(
            logicalNodeID: try BaselineTestSupport.logicalID(1),
            observations: []
        ))

        requireSendable(baseline)
        requireSendable(command)
        requireSendable(engine)
    }

    private func requireSendable<T: Sendable>(_ value: T) {
        _ = value
    }
}

nonisolated enum BaselineTestSupport {
    static func baselineID(_ value: Int = 1) -> BaselineID {
        let string = String(format: "89000000-0000-0000-0000-%012d", value)
        return BaselineID(UUID(uuidString: string)!)
    }

    static func logicalID(_ value: Int) throws -> LogicalNodeID {
        let string = String(format: "90000000-0000-0000-0000-%012d", value)
        return LogicalNodeID(try #require(UUID(uuidString: string)))
    }

    static func sourceID(_ value: Int) throws -> BSESourceID {
        let string = String(format: "91000000-0000-0000-0000-%012d", value)
        return BSESourceID(try #require(UUID(uuidString: string)))
    }

    static func provisionalID(_ value: Int) throws -> LogicalNodeID {
        let string = String(format: "92000000-0000-0000-0000-%012d", value)
        return LogicalNodeID(try #require(UUID(uuidString: string)))
    }

    static func date(_ offset: TimeInterval) -> Date {
        Date(timeIntervalSince1970: 1_700_000_000 + offset)
    }

    static func artifact(
        _ kind: String = "test.artifact",
        version: UInt64 = 1,
        bytes: [UInt8] = [1, 2, 3]
    ) throws -> RecognitionArtifact {
        RecognitionArtifact(
            kind: try RecognitionArtifactKind(kind),
            version: version,
            payload: Data(bytes)
        )
    }

    static func observation(
        source: Int,
        provisional: Int? = nil,
        firstObservedAt: Date? = nil,
        lastObservedAt: Date? = nil,
        presence: BaselineObservationPresence = .present
    ) throws -> BaselineObservation {
        try BaselineObservation(
            sourceID: sourceID(source),
            provisionalLogicalID: provisionalID(provisional ?? source),
            recognitionArtifacts: [artifact()],
            firstObservedAt: firstObservedAt ?? date(10),
            lastObservedAt: lastObservedAt ?? date(10),
            presence: presence
        )
    }

    static func emptyBaseline(
        schemaVersion: BaselineSchemaVersion = .current
    ) throws -> Baseline {
        try Baseline.empty(
            baselineID: baselineID(),
            schemaVersion: schemaVersion
        )
    }

    static func identityRecord(
        logicalID: LogicalNodeID,
        observations: [BaselineObservation]? = nil,
        revision: UInt64 = 1,
        baselineRevision: UInt64 = 1
    ) throws -> IdentityRecord {
        try IdentityRecord(
            logicalNodeID: logicalID,
            revision: IdentityRevision(revision),
            state: .active,
            observations: observations ?? [observation(source: 1)],
            metadata: IdentityRecordMetadata(
                createdInBaselineRevision: BaselineRevision(1),
                lastChangedInBaselineRevision: BaselineRevision(baselineRevision)
            )
        )
    }

    static func baselineWithIdentity(
        logicalID: LogicalNodeID? = nil,
        observations: [BaselineObservation]? = nil,
        schemaVersion: BaselineSchemaVersion = .current
    ) throws -> Baseline {
        let selectedID = try logicalID ?? self.logicalID(1)
        return try Baseline(
            baselineID: baselineID(),
            schemaVersion: schemaVersion,
            revision: BaselineRevision(1),
            identityRecords: [identityRecord(
                logicalID: selectedID,
                observations: observations
            )]
        )
    }
}
