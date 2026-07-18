//
//  MatchingPipeline.swift
//  BookmarkBridge
//

import Foundation

nonisolated protocol MatchingPipelineBaselineRepository: Sendable {
    func load() async throws -> Baseline?

    func apply(
        commands: [BaselineCommand],
        expectedRevision: BaselineRevision
    ) async throws -> BaselineChangeSet
}

extension BaselineRepository: MatchingPipelineBaselineRepository {}

nonisolated protocol IdentityReconciliationProcessing: Sendable {
    func reconcile(
        request: IdentityReconciliationRequest
    ) throws -> IdentityReconciliationResult
}

extension IdentityReconciliationEngine: IdentityReconciliationProcessing {}

/// Stateless coordinator from persisted Baseline and source snapshots to
/// durable logical snapshots. It performs exactly one Baseline transaction and
/// has no browser, similarity, diff, conflict, planning, or execution logic.
nonisolated struct MatchingPipeline: Sendable {
    private let baselineRepository: any MatchingPipelineBaselineRepository
    private let matchingEngine: any MatchingPipelineMatching
    private let groupBuilder: any IdentityMatchingGroupBuilding
    private let reconciliationEngine: any IdentityReconciliationProcessing

    init(
        baselineRepository: any MatchingPipelineBaselineRepository,
        matchingEngine: any MatchingPipelineMatching,
        groupBuilder: any IdentityMatchingGroupBuilding,
        reconciliationEngine: any IdentityReconciliationProcessing
    ) {
        self.baselineRepository = baselineRepository
        self.matchingEngine = matchingEngine
        self.groupBuilder = groupBuilder
        self.reconciliationEngine = reconciliationEngine
    }

    func execute(
        request: MatchingPipelineRequest
    ) async throws -> MatchingPipelineResult {
        let baselineBefore = try await loadBaseline()
        let snapshots = try validatedSnapshots(request.snapshots)
        let matchingGroups: [IdentityMatchingGroup]
        do {
            matchingGroups = try groupBuilder.build(
                baseline: baselineBefore,
                snapshots: snapshots,
                matchingEngine: matchingEngine
            )
        } catch {
            throw MatchingPipelineError.matchingFailure(
                MatchingPipelineFailureContext(error)
            )
        }

        let reconciliation: IdentityReconciliationResult
        do {
            reconciliation = try reconciliationEngine.reconcile(
                request: IdentityReconciliationRequest(
                    baseline: baselineBefore,
                    snapshots: snapshots,
                    matchingGroups: matchingGroups
                )
            )
        } catch {
            throw MatchingPipelineError.identityReconciliationFailure(
                MatchingPipelineFailureContext(error)
            )
        }

        let changeSet = try await applyBaselineTransaction(
            reconciliation.baselineCommands,
            expectedRevision: baselineBefore.revision
        )
        let report = makeReport(
            snapshots: snapshots,
            matchingGroups: matchingGroups,
            mutationCount: reconciliation.baselineCommands.count,
            changeSet: changeSet
        )
        return MatchingPipelineResult(
            baselineBefore: baselineBefore,
            baselineAfter: changeSet.baseline,
            logicalSnapshots: reconciliation.logicalSnapshots,
            reconciliationReport: reconciliation.report,
            pipelineReport: report
        )
    }

    private func loadBaseline() async throws -> Baseline {
        do {
            guard let baseline = try await baselineRepository.load() else {
                throw MatchingPipelineError.baselineNotFound
            }
            return baseline
        } catch let error as MatchingPipelineError {
            throw error
        } catch {
            throw MatchingPipelineError.baselineLoadFailure(
                MatchingPipelineFailureContext(error)
            )
        }
    }

    private func validatedSnapshots(
        _ snapshots: [BSESnapshot]
    ) throws -> [BSESnapshot] {
        var sources: Set<BSESourceID> = []
        for snapshot in snapshots {
            guard sources.insert(snapshot.source).inserted else {
                throw MatchingPipelineError.duplicateSnapshotSource(snapshot.source)
            }
        }
        return snapshots.sorted {
            $0.source.rawValue.uuidString < $1.source.rawValue.uuidString
        }
    }

    private func applyBaselineTransaction(
        _ commands: [BaselineCommand],
        expectedRevision: BaselineRevision
    ) async throws -> BaselineChangeSet {
        do {
            return try await baselineRepository.apply(
                commands: commands,
                expectedRevision: expectedRevision
            )
        } catch BaselineError.revisionConflict(let expected, let actual) {
            throw MatchingPipelineError.baselineRevisionConflict(
                expected: expected,
                actual: actual
            )
        } catch {
            throw MatchingPipelineError.baselineTransactionFailure(
                MatchingPipelineFailureContext(error)
            )
        }
    }

    private func makeReport(
        snapshots: [BSESnapshot],
        matchingGroups: [IdentityMatchingGroup],
        mutationCount: Int,
        changeSet: BaselineChangeSet
    ) -> MatchingPipelineReport {
        var matched = 0
        var unmatched = 0
        var ambiguous = 0
        for group in matchingGroups {
            switch group.matchingResult {
            case .match: matched += 1
            case .noMatch: unmatched += 1
            case .ambiguous: ambiguous += 1
            }
        }
        return MatchingPipelineReport(
            snapshotCount: snapshots.count,
            nodeCount: snapshots.reduce(0) { $0 + $1.tree.nodes.count },
            matchingGroupCount: matchingGroups.count,
            matchedGroupCount: matched,
            unmatchedGroupCount: unmatched,
            ambiguousGroupCount: ambiguous,
            baselineMutationCount: mutationCount,
            baselineTransactionPersisted: mutationCount > 0,
            baselineRevisionBefore: changeSet.revisionBefore,
            baselineRevisionAfter: changeSet.revisionAfter
        )
    }
}
