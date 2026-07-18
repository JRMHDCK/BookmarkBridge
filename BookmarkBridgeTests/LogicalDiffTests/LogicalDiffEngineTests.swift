//
//  LogicalDiffEngineTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("BSE Logical Diff")
struct LogicalDiffEngineTests {
    @Test("Identical Baseline presence and logical snapshot are unchanged")
    func noChange() throws {
        let sourceID = LogicalDiffTestSupport.sourceID(1)
        let logicalID = LogicalDiffTestSupport.logicalID(1)
        let baseline = try LogicalDiffTestSupport.baseline(records: [
            LogicalDiffTestSupport.record(
                logicalID: logicalID,
                observations: [LogicalDiffTestSupport.observation(
                    sourceID: sourceID,
                    provisionalID: LogicalDiffTestSupport.logicalID(101)
                )]
            ),
        ])
        let snapshot = try LogicalDiffTestSupport.snapshot(
            sourceID: sourceID,
            logicalIDs: [logicalID]
        )

        let result = try LogicalDiffEngine().diff(request: LogicalDiffRequest(
            baseline: baseline,
            logicalSnapshots: [snapshot]
        ))

        #expect(result.identityChanges.isEmpty)
        #expect(result.observationChanges.isEmpty)
        #expect(result.unchangedIdentityIDs == [logicalID])
        #expect(result.report.unchangedIdentityCount == 1)
    }

    @Test("An unknown logical identity is created once")
    func creation() throws {
        let sourceID = LogicalDiffTestSupport.sourceID(1)
        let logicalID = LogicalDiffTestSupport.logicalID(1)
        let result = try LogicalDiffEngine().diff(request: LogicalDiffRequest(
            baseline: LogicalDiffTestSupport.emptyBaseline(),
            logicalSnapshots: [LogicalDiffTestSupport.snapshot(
                sourceID: sourceID,
                logicalIDs: [logicalID]
            )]
        ))

        #expect(result.identityChanges == [.created(logicalNodeID: logicalID)])
        #expect(result.observationChanges == [
            .added(logicalNodeID: logicalID, sourceID: sourceID),
        ])
        #expect(result.report.createdIdentityCount == 1)
    }

    @Test("A restored observation updates an active identity")
    func update() throws {
        let sourceID = LogicalDiffTestSupport.sourceID(1)
        let logicalID = LogicalDiffTestSupport.logicalID(1)
        let baseline = try LogicalDiffTestSupport.baseline(records: [
            LogicalDiffTestSupport.record(
                logicalID: logicalID,
                observations: [LogicalDiffTestSupport.observation(
                    sourceID: sourceID,
                    provisionalID: LogicalDiffTestSupport.logicalID(101),
                    presence: .absent
                )]
            ),
        ])

        let result = try LogicalDiffEngine().diff(request: LogicalDiffRequest(
            baseline: baseline,
            logicalSnapshots: [LogicalDiffTestSupport.snapshot(
                sourceID: sourceID,
                logicalIDs: [logicalID]
            )]
        ))

        #expect(result.identityChanges == [.updated(logicalNodeID: logicalID)])
        #expect(result.observationChanges == [
            .restored(logicalNodeID: logicalID, sourceID: sourceID),
        ])
        #expect(result.report.updatedIdentityCount == 1)
    }

    @Test("A fully observed disappearance archives an active identity")
    func archival() throws {
        let sourceID = LogicalDiffTestSupport.sourceID(1)
        let logicalID = LogicalDiffTestSupport.logicalID(1)
        let baseline = try LogicalDiffTestSupport.baseline(records: [
            LogicalDiffTestSupport.record(
                logicalID: logicalID,
                observations: [LogicalDiffTestSupport.observation(
                    sourceID: sourceID,
                    provisionalID: LogicalDiffTestSupport.logicalID(101)
                )]
            ),
        ])

        let result = try LogicalDiffEngine().diff(request: LogicalDiffRequest(
            baseline: baseline,
            logicalSnapshots: [LogicalDiffTestSupport.snapshot(
                sourceID: sourceID,
                logicalIDs: []
            )]
        ))

        #expect(result.identityChanges == [.archived(logicalNodeID: logicalID)])
        #expect(result.observationChanges == [
            .removed(logicalNodeID: logicalID, sourceID: sourceID),
        ])
        #expect(result.report.archivedIdentityCount == 1)
    }

    @Test("An observed archived identity is reactivated")
    func reactivation() throws {
        let sourceID = LogicalDiffTestSupport.sourceID(1)
        let logicalID = LogicalDiffTestSupport.logicalID(1)
        let baseline = try LogicalDiffTestSupport.baseline(records: [
            LogicalDiffTestSupport.record(
                logicalID: logicalID,
                state: .archived,
                observations: [LogicalDiffTestSupport.observation(
                    sourceID: sourceID,
                    provisionalID: LogicalDiffTestSupport.logicalID(101)
                )]
            ),
        ])

        let result = try LogicalDiffEngine().diff(request: LogicalDiffRequest(
            baseline: baseline,
            logicalSnapshots: [LogicalDiffTestSupport.snapshot(
                sourceID: sourceID,
                logicalIDs: [logicalID]
            )]
        ))

        #expect(result.identityChanges == [
            .reactivated(logicalNodeID: logicalID, previousState: .archived),
        ])
        #expect(result.observationChanges.isEmpty)
        #expect(result.report.reactivatedIdentityCount == 1)
    }

    @Test("Presence in a new requested source adds an observation")
    func observationAddition() throws {
        let firstSource = LogicalDiffTestSupport.sourceID(1)
        let secondSource = LogicalDiffTestSupport.sourceID(2)
        let logicalID = LogicalDiffTestSupport.logicalID(1)
        let baseline = try LogicalDiffTestSupport.baseline(records: [
            LogicalDiffTestSupport.record(
                logicalID: logicalID,
                observations: [LogicalDiffTestSupport.observation(
                    sourceID: firstSource,
                    provisionalID: LogicalDiffTestSupport.logicalID(101)
                )]
            ),
        ])
        let snapshots = try [firstSource, secondSource].map {
            try LogicalDiffTestSupport.snapshot(sourceID: $0, logicalIDs: [logicalID])
        }

        let result = try LogicalDiffEngine().diff(request: LogicalDiffRequest(
            baseline: baseline,
            logicalSnapshots: snapshots
        ))

        #expect(result.identityChanges == [.updated(logicalNodeID: logicalID)])
        #expect(result.observationChanges == [
            .added(logicalNodeID: logicalID, sourceID: secondSource),
        ])
    }

    @Test("One removed observation does not archive an identity present elsewhere")
    func observationRemoval() throws {
        let firstSource = LogicalDiffTestSupport.sourceID(1)
        let secondSource = LogicalDiffTestSupport.sourceID(2)
        let logicalID = LogicalDiffTestSupport.logicalID(1)
        let baseline = try LogicalDiffTestSupport.baseline(records: [
            LogicalDiffTestSupport.record(
                logicalID: logicalID,
                observations: [
                    LogicalDiffTestSupport.observation(
                        sourceID: firstSource,
                        provisionalID: LogicalDiffTestSupport.logicalID(101)
                    ),
                    LogicalDiffTestSupport.observation(
                        sourceID: secondSource,
                        provisionalID: LogicalDiffTestSupport.logicalID(102)
                    ),
                ]
            ),
        ])
        let snapshots = try [
            LogicalDiffTestSupport.snapshot(sourceID: firstSource, logicalIDs: []),
            LogicalDiffTestSupport.snapshot(sourceID: secondSource, logicalIDs: [logicalID]),
        ]

        let result = try LogicalDiffEngine().diff(request: LogicalDiffRequest(
            baseline: baseline,
            logicalSnapshots: snapshots
        ))

        #expect(result.identityChanges == [.updated(logicalNodeID: logicalID)])
        #expect(result.observationChanges == [
            .removed(logicalNodeID: logicalID, sourceID: firstSource),
        ])
    }

    @Test("An absent source never implies observation removal or archival")
    func absentSource() throws {
        let absentSource = LogicalDiffTestSupport.sourceID(1)
        let requestedSource = LogicalDiffTestSupport.sourceID(2)
        let logicalID = LogicalDiffTestSupport.logicalID(1)
        let baseline = try LogicalDiffTestSupport.baseline(records: [
            LogicalDiffTestSupport.record(
                logicalID: logicalID,
                observations: [LogicalDiffTestSupport.observation(
                    sourceID: absentSource,
                    provisionalID: LogicalDiffTestSupport.logicalID(101)
                )]
            ),
        ])

        let result = try LogicalDiffEngine().diff(request: LogicalDiffRequest(
            baseline: baseline,
            logicalSnapshots: [LogicalDiffTestSupport.snapshot(
                sourceID: requestedSource,
                logicalIDs: []
            )]
        ))

        #expect(result.identityChanges.isEmpty)
        #expect(result.observationChanges.isEmpty)
        #expect(result.unchangedIdentityIDs == [logicalID])
    }

    @Test("Recognition artifacts are opaque and never affect the diff")
    func recognitionArtifactsAreIgnored() throws {
        let sourceID = LogicalDiffTestSupport.sourceID(1)
        let logicalID = LogicalDiffTestSupport.logicalID(1)
        let artifact = RecognitionArtifact(
            kind: try RecognitionArtifactKind("test.opaque"),
            version: 7,
            payload: Data([1, 2, 3])
        )
        let withoutArtifact = try LogicalDiffTestSupport.baseline(records: [
            LogicalDiffTestSupport.record(
                logicalID: logicalID,
                observations: [LogicalDiffTestSupport.observation(
                    sourceID: sourceID,
                    provisionalID: LogicalDiffTestSupport.logicalID(101)
                )]
            ),
        ])
        let withArtifact = try LogicalDiffTestSupport.baseline(records: [
            LogicalDiffTestSupport.record(
                logicalID: logicalID,
                observations: [LogicalDiffTestSupport.observation(
                    sourceID: sourceID,
                    provisionalID: LogicalDiffTestSupport.logicalID(101),
                    recognitionArtifacts: [artifact]
                )]
            ),
        ])
        let snapshot = try LogicalDiffTestSupport.snapshot(
            sourceID: sourceID,
            logicalIDs: [logicalID]
        )
        let engine = LogicalDiffEngine()

        let first = try engine.diff(request: LogicalDiffRequest(
            baseline: withoutArtifact,
            logicalSnapshots: [snapshot]
        ))
        let second = try engine.diff(request: LogicalDiffRequest(
            baseline: withArtifact,
            logicalSnapshots: [snapshot]
        ))

        #expect(first == second)
    }

    @Test("Diffing never mutates either immutable input")
    func inputsRemainUnchanged() throws {
        let baseline = try LogicalDiffTestSupport.emptyBaseline()
        let snapshot = try LogicalDiffTestSupport.snapshot(
            sourceID: LogicalDiffTestSupport.sourceID(1),
            logicalIDs: [LogicalDiffTestSupport.logicalID(1)]
        )
        let baselineBefore = baseline
        let snapshotBefore = snapshot

        _ = try LogicalDiffEngine().diff(request: LogicalDiffRequest(
            baseline: baseline,
            logicalSnapshots: [snapshot]
        ))

        #expect(baseline == baselineBefore)
        #expect(snapshot == snapshotBefore)
    }

    @Test("Input ordering does not affect the complete result")
    func deterministic() throws {
        let logicalID = LogicalDiffTestSupport.logicalID(1)
        let snapshots = try [1, 2].map {
            try LogicalDiffTestSupport.snapshot(
                sourceID: LogicalDiffTestSupport.sourceID($0),
                logicalIDs: [logicalID]
            )
        }
        let baseline = try LogicalDiffTestSupport.emptyBaseline()
        let engine = LogicalDiffEngine()

        let first = try engine.diff(request: LogicalDiffRequest(
            baseline: baseline,
            logicalSnapshots: snapshots
        ))
        let second = try engine.diff(request: LogicalDiffRequest(
            baseline: baseline,
            logicalSnapshots: Array(snapshots.reversed())
        ))

        #expect(first == second)
    }

    @Test("A non-current Baseline schema is rejected explicitly")
    func invalidBaseline() throws {
        let baseline = try Baseline(
            baselineID: BaselineID(LogicalDiffTestSupport.uuid(900)),
            schemaVersion: BaselineSchemaVersion(2),
            revision: .zero,
            identityRecords: []
        )

        #expect(throws: LogicalDiffError.invalidBaseline) {
            _ = try LogicalDiffEngine().diff(request: LogicalDiffRequest(
                baseline: baseline,
                logicalSnapshots: []
            ))
        }
    }

    @Test("The same logical node repeated for one source is rejected")
    func duplicateLogicalNode() throws {
        let sourceID = LogicalDiffTestSupport.sourceID(1)
        let logicalID = LogicalDiffTestSupport.logicalID(1)
        let snapshots = try [1, 2].map { _ in
            try LogicalDiffTestSupport.snapshot(
                sourceID: sourceID,
                logicalIDs: [logicalID]
            )
        }

        #expect(throws: LogicalDiffError.duplicateLogicalNode(
            logicalNodeID: logicalID,
            sourceID: sourceID
        )) {
            _ = try LogicalDiffEngine().diff(request: LogicalDiffRequest(
                baseline: LogicalDiffTestSupport.emptyBaseline(),
                logicalSnapshots: snapshots
            ))
        }
    }

    @Test("One durable identity cannot have different node kinds")
    func inconsistentState() throws {
        let logicalID = LogicalDiffTestSupport.logicalID(1)
        let folderSnapshot = try LogicalDiffTestSupport.snapshot(
            sourceID: LogicalDiffTestSupport.sourceID(1),
            logicalIDs: [logicalID]
        )
        let bookmarkSnapshot = try LogicalDiffTestSupport.bookmarkSnapshot(
            sourceID: LogicalDiffTestSupport.sourceID(2),
            logicalID: logicalID
        )

        #expect(throws: LogicalDiffError.inconsistentState(logicalID)) {
            _ = try LogicalDiffEngine().diff(request: LogicalDiffRequest(
                baseline: LogicalDiffTestSupport.emptyBaseline(),
                logicalSnapshots: [folderSnapshot, bookmarkSnapshot]
            ))
        }
    }

    @Test("Models and engine satisfy Swift Concurrency boundaries")
    func strictConcurrency() throws {
        let request = LogicalDiffRequest(
            baseline: try LogicalDiffTestSupport.emptyBaseline(),
            logicalSnapshots: []
        )

        requireSendable(LogicalDiffEngine())
        requireSendable(request)
        requireSendable(try LogicalDiffEngine().diff(request: request))
    }

    private func requireSendable<T: Sendable>(_ value: T) { _ = value }
}

private enum LogicalDiffTestSupport {
    static func emptyBaseline() throws -> Baseline {
        try Baseline.empty(baselineID: BaselineID(uuid(900)))
    }

    static func baseline(records: [IdentityRecord]) throws -> Baseline {
        try Baseline(
            baselineID: BaselineID(uuid(900)),
            schemaVersion: .current,
            revision: BaselineRevision(records.isEmpty ? 0 : 1),
            identityRecords: records
        )
    }

    static func record(
        logicalID: LogicalNodeID,
        state: IdentityRecordState = .active,
        observations: [BaselineObservation]
    ) throws -> IdentityRecord {
        try IdentityRecord(
            logicalNodeID: logicalID,
            revision: IdentityRevision(1),
            state: state,
            observations: observations,
            metadata: IdentityRecordMetadata(
                createdInBaselineRevision: BaselineRevision(1),
                lastChangedInBaselineRevision: BaselineRevision(1)
            )
        )
    }

    static func observation(
        sourceID: BSESourceID,
        provisionalID: LogicalNodeID,
        presence: BaselineObservationPresence = .present,
        recognitionArtifacts: [RecognitionArtifact] = []
    ) throws -> BaselineObservation {
        try BaselineObservation(
            sourceID: sourceID,
            provisionalLogicalID: provisionalID,
            recognitionArtifacts: recognitionArtifacts,
            firstObservedAt: Date(timeIntervalSince1970: 10),
            lastObservedAt: Date(timeIntervalSince1970: 10),
            presence: presence
        )
    }

    static func snapshot(
        sourceID: BSESourceID,
        logicalIDs: [LogicalNodeID]
    ) throws -> LogicalSnapshot {
        LogicalSnapshot(
            source: sourceID,
            capturedAt: Date(timeIntervalSince1970: 20),
            tree: try BSETree(nodes: logicalIDs.enumerated().map { index, logicalID in
                try BSENode(
                    logicalID: logicalID,
                    kind: .folder,
                    title: "Folder \(index)",
                    position: index
                )
            })
        )
    }

    static func bookmarkSnapshot(
        sourceID: BSESourceID,
        logicalID: LogicalNodeID
    ) throws -> LogicalSnapshot {
        let rootID = LogicalNodeID(uuid(800))
        return LogicalSnapshot(
            source: sourceID,
            capturedAt: Date(timeIntervalSince1970: 20),
            tree: try BSETree(nodes: [
                BSENode(
                    logicalID: rootID,
                    kind: .folder,
                    title: "Root",
                    position: 0
                ),
                BSENode(
                    logicalID: logicalID,
                    kind: .bookmark,
                    title: "Bookmark",
                    parentID: rootID,
                    position: 0,
                    url: URL(string: "https://example.com")
                ),
            ])
        )
    }

    static func sourceID(_ value: Int) -> BSESourceID {
        BSESourceID(uuid(value))
    }

    static func logicalID(_ value: Int) -> LogicalNodeID {
        LogicalNodeID(uuid(value))
    }

    static func uuid(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}
