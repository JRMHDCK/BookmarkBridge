//
//  IdentityReconciliationEngine.swift
//  BookmarkBridge
//

import Foundation

/// Stateless orchestration of supplied identity decisions into durable mappings.
/// It never compares node content or persists the generated commands.
nonisolated struct IdentityReconciliationEngine: Sendable {
    private let identityProvider: any IdentityProvider
    private let matchingPolicy: any IdentityMatchingPolicy
    private let snapshotBuilder: any LogicalSnapshotBuilding

    init(
        identityProvider: any IdentityProvider,
        matchingPolicy: any IdentityMatchingPolicy,
        snapshotBuilder: any LogicalSnapshotBuilding
    ) {
        self.identityProvider = identityProvider
        self.matchingPolicy = matchingPolicy
        self.snapshotBuilder = snapshotBuilder
    }

    func reconcile(
        request: IdentityReconciliationRequest
    ) throws -> IdentityReconciliationResult {
        let snapshots = try validatedSnapshots(request.snapshots)
        let nodesByReference = nodeIndex(snapshots)
        let groups = try validatedGroups(
            request.matchingGroups,
            nodesByReference: nodesByReference
        )

        var assignments: [LogicalIdentityAssignment] = []
        var commands: [BaselineCommand] = []
        var created: [CreatedIdentityReport] = []
        var reused: [ReusedIdentityReport] = []
        var ambiguities: [IdentityAmbiguityReport] = []
        var unresolved: Set<IdentityNodeReference> = []
        var assignedLogicalIDs: Set<LogicalNodeID> = []

        for group in groups {
            let decision = try matchingPolicy.decide(for: IdentityMatchingContext(
                baseline: request.baseline,
                group: group
            ))
            switch decision {
            case .create:
                let logicalNodeID = try identityProvider.nextLogicalNodeID()
                guard request.baseline.identity(logicalNodeID) == nil,
                      assignedLogicalIDs.insert(logicalNodeID).inserted else {
                    throw IdentityReconciliationError.identityCollision(logicalNodeID)
                }
                let observations = try group.members.map { reference in
                    try newObservation(
                        reference,
                        capturedAt: try capturedAt(
                            for: reference.sourceID,
                            snapshots: snapshots
                        )
                    )
                }
                commands.append(.createIdentity(CreateIdentityCommand(
                    logicalNodeID: logicalNodeID,
                    observations: observations
                )))
                assignments.append(contentsOf: assignmentsForGroup(
                    group,
                    logicalNodeID: logicalNodeID
                ))
                created.append(CreatedIdentityReport(
                    logicalNodeID: logicalNodeID,
                    members: group.members
                ))

            case .reuse(let logicalNodeID):
                guard assignedLogicalIDs.insert(logicalNodeID).inserted else {
                    throw IdentityReconciliationError.identityCollision(logicalNodeID)
                }
                guard let record = request.baseline.identity(logicalNodeID) else {
                    throw IdentityReconciliationError.reusedIdentityNotFound(logicalNodeID)
                }
                commands.append(contentsOf: try reuseCommands(
                    for: record,
                    members: group.members,
                    snapshots: snapshots
                ))
                assignments.append(contentsOf: assignmentsForGroup(
                    group,
                    logicalNodeID: logicalNodeID
                ))
                reused.append(ReusedIdentityReport(
                    logicalNodeID: logicalNodeID,
                    members: group.members
                ))

            case .ambiguous(let candidateIDs):
                ambiguities.append(IdentityAmbiguityReport(
                    members: group.members,
                    candidateIDs: candidateIDs.sorted()
                ))
                unresolved.formUnion(group.members)
            }
        }

        let groupedReferences = Set(groups.flatMap(\.members))
        let ungrouped = Set(nodesByReference.keys).subtracting(groupedReferences)
        unresolved.formUnion(ungrouped)

        let logicalSnapshots = try buildCompleteSnapshots(
            snapshots,
            assignments: assignments,
            unresolved: unresolved
        )
        let diagnostics = diagnosticsFor(
            snapshots: snapshots,
            unresolved: unresolved,
            logicalSnapshots: logicalSnapshots
        )
        let orderedUnresolved = unresolved.sorted()
        let report = IdentityReconciliationReport(
            createdIdentities: created,
            reusedIdentities: reused,
            ambiguities: ambiguities,
            unresolvedObjects: orderedUnresolved,
            diagnostics: diagnostics,
            statistics: IdentityReconciliationStatistics(
                snapshotCount: snapshots.count,
                logicalSnapshotCount: logicalSnapshots.count,
                groupCount: groups.count,
                createdIdentityCount: created.count,
                reusedIdentityCount: reused.count,
                ambiguityCount: ambiguities.count,
                unresolvedObjectCount: orderedUnresolved.count,
                baselineCommandCount: commands.count
            )
        )
        return IdentityReconciliationResult(
            logicalSnapshots: logicalSnapshots,
            baselineCommands: commands,
            report: report
        )
    }

    private func validatedSnapshots(
        _ snapshots: [BSESnapshot]
    ) throws -> [BSESnapshot] {
        var sources: Set<BSESourceID> = []
        for snapshot in snapshots {
            guard sources.insert(snapshot.source).inserted else {
                throw IdentityReconciliationError.duplicateSnapshotSource(snapshot.source)
            }
        }
        return snapshots.sorted {
            $0.source.rawValue.uuidString < $1.source.rawValue.uuidString
        }
    }

    private func nodeIndex(
        _ snapshots: [BSESnapshot]
    ) -> [IdentityNodeReference: BSENode] {
        Dictionary(uniqueKeysWithValues: snapshots.flatMap { snapshot in
            snapshot.tree.nodes.map { node in
                (
                    IdentityNodeReference(
                        sourceID: snapshot.source,
                        provisionalLogicalID: node.logicalID
                    ),
                    node
                )
            }
        })
    }

    private func validatedGroups(
        _ groups: [IdentityMatchingGroup],
        nodesByReference: [IdentityNodeReference: BSENode]
    ) throws -> [IdentityMatchingGroup] {
        var allMembers: Set<IdentityNodeReference> = []
        for group in groups {
            guard !group.members.isEmpty else {
                throw IdentityReconciliationError.emptyMatchingGroup
            }
            var sources: Set<BSESourceID> = []
            for member in group.members {
                guard nodesByReference[member] != nil else {
                    throw IdentityReconciliationError.unknownNodeReference(member)
                }
                guard allMembers.insert(member).inserted else {
                    throw IdentityReconciliationError.duplicateGroupMember(member)
                }
                guard sources.insert(member.sourceID).inserted else {
                    throw IdentityReconciliationError.multipleMembersForSource(member.sourceID)
                }
            }
        }
        return groups.sorted { lhs, rhs in
            guard let lhsFirst = lhs.members.first, let rhsFirst = rhs.members.first else {
                return lhs.members.count < rhs.members.count
            }
            return lhsFirst < rhsFirst
        }
    }

    private func assignmentsForGroup(
        _ group: IdentityMatchingGroup,
        logicalNodeID: LogicalNodeID
    ) -> [LogicalIdentityAssignment] {
        group.members.map { reference in
            LogicalIdentityAssignment(
                sourceID: reference.sourceID,
                provisionalLogicalID: reference.provisionalLogicalID,
                logicalNodeID: logicalNodeID
            )
        }
    }

    private func newObservation(
        _ reference: IdentityNodeReference,
        capturedAt: Date
    ) throws -> BaselineObservation {
        try BaselineObservation(
            sourceID: reference.sourceID,
            provisionalLogicalID: reference.provisionalLogicalID,
            recognitionArtifacts: [],
            firstObservedAt: capturedAt,
            lastObservedAt: capturedAt,
            presence: .present
        )
    }

    private func reuseCommands(
        for record: IdentityRecord,
        members: [IdentityNodeReference],
        snapshots: [BSESnapshot]
    ) throws -> [BaselineCommand] {
        var commands: [BaselineCommand] = []
        var expectedRevision = record.revision

        if record.state != .active {
            commands.append(.reactivateIdentity(ReactivateIdentityCommand(
                logicalNodeID: record.logicalNodeID,
                expectedIdentityRevision: expectedRevision
            )))
            expectedRevision = try expectedRevision.incremented()
        }

        for reference in members.sorted() {
            let observedAt = try capturedAt(
                for: reference.sourceID,
                snapshots: snapshots
            )
            let observation: BaselineObservation
            if let existing = record.observations.first(where: {
                $0.sourceID == reference.sourceID
            }) {
                guard observedAt >= existing.lastObservedAt
                    || existing.provisionalLogicalID == reference.provisionalLogicalID else {
                    throw IdentityReconciliationError.observationTimeRegression(reference)
                }
                observation = try BaselineObservation(
                    sourceID: existing.sourceID,
                    provisionalLogicalID: reference.provisionalLogicalID,
                    recognitionArtifacts: existing.recognitionArtifacts,
                    firstObservedAt: existing.firstObservedAt,
                    lastObservedAt: max(existing.lastObservedAt, observedAt),
                    presence: .present
                )
                if observation == existing { continue }
            } else {
                observation = try newObservation(reference, capturedAt: observedAt)
            }

            commands.append(.updateObservation(UpdateObservationCommand(
                logicalNodeID: record.logicalNodeID,
                expectedIdentityRevision: expectedRevision,
                observation: observation
            )))
            expectedRevision = try expectedRevision.incremented()
        }
        return commands
    }

    private func capturedAt(
        for sourceID: BSESourceID,
        snapshots: [BSESnapshot]
    ) throws -> Date {
        guard let capturedAt = snapshots.first(where: {
            $0.source == sourceID
        })?.capturedAt else {
            throw IdentityReconciliationError.assignmentSourceMismatch(sourceID)
        }
        return capturedAt
    }

    private func buildCompleteSnapshots(
        _ snapshots: [BSESnapshot],
        assignments: [LogicalIdentityAssignment],
        unresolved: Set<IdentityNodeReference>
    ) throws -> [LogicalSnapshot] {
        try snapshots.compactMap { snapshot in
            let sourceUnresolved = unresolved.contains { $0.sourceID == snapshot.source }
            guard !sourceUnresolved else { return nil }
            return try snapshotBuilder.build(
                from: snapshot,
                assignments: assignments.filter { $0.sourceID == snapshot.source }
            )
        }
    }

    private func diagnosticsFor(
        snapshots: [BSESnapshot],
        unresolved: Set<IdentityNodeReference>,
        logicalSnapshots: [LogicalSnapshot]
    ) -> [IdentityReconciliationDiagnostic] {
        let unmatched = unresolved.sorted().map {
            IdentityReconciliationDiagnostic.unmatchedNode($0)
        }
        let completedSources = Set(logicalSnapshots.map(\.source))
        let incomplete = snapshots
            .filter { !completedSources.contains($0.source) }
            .map { IdentityReconciliationDiagnostic.snapshotIncomplete(sourceID: $0.source) }
        return unmatched + incomplete
    }
}
