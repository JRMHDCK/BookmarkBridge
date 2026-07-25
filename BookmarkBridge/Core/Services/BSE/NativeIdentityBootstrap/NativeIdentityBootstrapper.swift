//
//  NativeIdentityBootstrapper.swift
//  BookmarkBridge
//

import Foundation

/// Validates and installs durable-to-native correspondences observed during
/// the same source reads that fed identity reconciliation.
nonisolated struct NativeIdentityBootstrapper: Sendable {
    private let repository: any NativeIdentityRepository

    init(repository: any NativeIdentityRepository) {
        self.repository = repository
    }

    /// Uses the reconciliation report because it is the existing result that
    /// explicitly retains provisional-to-durable assignments. A
    /// `LogicalSnapshot` contains only durable IDs and cannot safely recreate
    /// this relation without relying on node position.
    func bootstrap(
        reconciliationReport: IdentityReconciliationReport,
        observations: [NativeIdentityObservation]
    ) throws -> NativeIdentityBootstrapResult {
        let assignments = try assignmentsByReference(from: reconciliationReport)
        let desired = try desiredMappings(
            observations: observations,
            assignments: assignments
        )
        let mutations = try repositoryMutations(desired)
        let mutationResult = try repository.applyAtomically(mutations)

        return NativeIdentityBootstrapResult(
            observationsProcessed: observations.count,
            mappingsCreated: mutationResult.registrationsApplied,
            mappingsAlreadyPresent:
                mutationResult.registrationsAlreadyPresent,
            migrationsApplied: mutationResult.migrationsApplied,
            conflictsDetected: 0
        )
    }

    private func assignmentsByReference(
        from report: IdentityReconciliationReport
    ) throws -> [IdentityNodeReference: LogicalNodeID] {
        let resolved = report.createdIdentities.map {
            ($0.logicalNodeID, $0.members)
        } + report.reusedIdentities.map {
            ($0.logicalNodeID, $0.members)
        }
        var assignments: [IdentityNodeReference: LogicalNodeID] = [:]
        for (logicalNodeID, members) in resolved {
            for reference in members {
                if let existing = assignments[reference], existing != logicalNodeID {
                    throw NativeIdentityBootstrapError.inconsistentReconciliation(
                        reference: reference,
                        first: existing,
                        second: logicalNodeID
                    )
                }
                assignments[reference] = logicalNodeID
            }
        }
        return assignments
    }

    private func desiredMappings(
        observations: [NativeIdentityObservation],
        assignments: [IdentityNodeReference: LogicalNodeID]
    ) throws -> [DesiredNativeIdentity] {
        var nativeByReference: [IdentityNodeReference: NativeNodeIdentifier] = [:]
        var desiredByLogical: [LogicalMappingKey: DesiredNativeIdentity] = [:]
        var logicalByNative: [NativeMappingKey: LogicalNodeID] = [:]

        for observation in observations {
            let reference = IdentityNodeReference(
                sourceID: observation.sourceID,
                provisionalLogicalID: observation.provisionalLogicalNodeID
            )
            if let existing = nativeByReference[reference] {
                throw NativeIdentityBootstrapError.duplicateObservation(
                    reference: reference,
                    first: existing,
                    second: observation.nativeIdentifier
                )
            }
            nativeByReference[reference] = observation.nativeIdentifier
            guard let durableID = assignments[reference] else {
                throw NativeIdentityBootstrapError.observationWithoutDurableIdentity(
                    observation
                )
            }

            let logicalKey = LogicalMappingKey(
                sourceID: observation.sourceID,
                logicalNodeID: durableID
            )
            if let existing = desiredByLogical[logicalKey],
               existing.mapping.nativeIdentifier != observation.nativeIdentifier {
                throw NativeIdentityBootstrapError.durableLogicalNodeConflict(
                    sourceID: observation.sourceID,
                    logicalNodeID: durableID,
                    existing: existing.mapping.nativeIdentifier,
                    observed: observation.nativeIdentifier
                )
            }

            let nativeKey = NativeMappingKey(
                sourceID: observation.sourceID,
                nativeIdentifier: observation.nativeIdentifier
            )
            if let existing = logicalByNative[nativeKey], existing != durableID {
                throw NativeIdentityBootstrapError.nativeIdentifierConflict(
                    sourceID: observation.sourceID,
                    nativeIdentifier: observation.nativeIdentifier,
                    existing: existing,
                    observed: durableID
                )
            }

            desiredByLogical[logicalKey] = DesiredNativeIdentity(
                mapping: NativeIdentityMapping(
                    logicalNodeID: durableID,
                    sourceID: observation.sourceID,
                    nativeIdentifier: observation.nativeIdentifier
                ),
                observation: observation
            )
            logicalByNative[nativeKey] = durableID
        }

        return Array(desiredByLogical.values)
    }

    private func repositoryMutations(
        _ desired: [DesiredNativeIdentity]
    ) throws -> [NativeIdentityRepositoryMutation] {
        var mutations: [NativeIdentityRepositoryMutation] = []
        for item in desired.sorted(by: {
            mappingOrder($0.mapping, $1.mapping)
        }) {
            let mapping = item.mapping
            let existingNative = repository.nativeIdentifier(
                for: mapping.logicalNodeID,
                sourceID: mapping.sourceID
            )
            let existingLogical = repository.logicalNodeID(
                for: mapping.nativeIdentifier,
                sourceID: mapping.sourceID
            )

            if let existingLogical, existingLogical != mapping.logicalNodeID {
                throw NativeIdentityBootstrapError.nativeIdentifierConflict(
                    sourceID: mapping.sourceID,
                    nativeIdentifier: mapping.nativeIdentifier,
                    existing: existingLogical,
                    observed: mapping.logicalNodeID
                )
            }

            switch (existingNative, existingLogical) {
            case (nil, nil):
                mutations.append(.register(mapping))
            case (.some(let existingNative), .some):
                if existingNative == mapping.nativeIdentifier {
                    mutations.append(.register(mapping))
                } else {
                    mutations.append(.migrate(try migration(
                        item,
                        from: existingNative
                    )))
                }
            case (.some, nil), (nil, .some):
                if let existingNative,
                   existingNative != mapping.nativeIdentifier,
                   existingLogical == nil {
                    mutations.append(.migrate(try migration(
                        item,
                        from: existingNative
                    )))
                    continue
                }
                throw NativeIdentityBootstrapError.inconsistentRepository(
                    sourceID: mapping.sourceID,
                    logicalNodeID: mapping.logicalNodeID,
                    nativeIdentifier: mapping.nativeIdentifier
                )
            }
        }
        return mutations
    }

    private func migration(
        _ desired: DesiredNativeIdentity,
        from existing: NativeNodeIdentifier
    ) throws -> NativeIdentityMigration {
        let observation = desired.observation
        guard observation.nativeIdentityKind == .chromeGUID,
              observation.continuityIdentityKind == .chromeIDFallback,
              let continuity = observation.continuityIdentifier else {
            throw NativeIdentityBootstrapError.durableLogicalNodeConflict(
                sourceID: desired.mapping.sourceID,
                logicalNodeID: desired.mapping.logicalNodeID,
                existing: existing,
                observed: desired.mapping.nativeIdentifier
            )
        }
        return NativeIdentityMigration(
            logicalNodeID: desired.mapping.logicalNodeID,
            sourceID: desired.mapping.sourceID,
            from: existing,
            fromKind: .chromeIDFallback,
            to: desired.mapping.nativeIdentifier,
            toKind: .chromeGUID,
            continuityProof: continuity,
            continuityProofKind: .chromeIDFallback
        )
    }

    private func mappingOrder(
        _ lhs: NativeIdentityMapping,
        _ rhs: NativeIdentityMapping
    ) -> Bool {
        let lhsSource = lhs.sourceID.rawValue.uuidString
        let rhsSource = rhs.sourceID.rawValue.uuidString
        if lhsSource != rhsSource { return lhsSource < rhsSource }
        if lhs.logicalNodeID != rhs.logicalNodeID {
            return lhs.logicalNodeID < rhs.logicalNodeID
        }
        return lhs.nativeIdentifier.rawValue < rhs.nativeIdentifier.rawValue
    }
}

nonisolated private struct LogicalMappingKey: Hashable, Sendable {
    let sourceID: BSESourceID
    let logicalNodeID: LogicalNodeID
}

nonisolated private struct NativeMappingKey: Hashable, Sendable {
    let sourceID: BSESourceID
    let nativeIdentifier: NativeNodeIdentifier
}

nonisolated private struct DesiredNativeIdentity: Sendable {
    let mapping: NativeIdentityMapping
    let observation: NativeIdentityObservation
}
