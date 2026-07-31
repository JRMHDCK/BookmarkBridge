//
//  ConfirmedSynchronizationPlan.swift
//  BookmarkBridge
//

import CryptoKit
import Foundation

nonisolated struct SynchronizationPlanFingerprint:
    Hashable,
    Codable,
    Sendable
{
    let rawValue: String
}

nonisolated struct SynchronizationSnapshotFingerprint:
    Hashable,
    Codable,
    Sendable
{
    let rawValue: String
}

/// Immutable user-confirmed plan and the exact read state from which it was
/// derived. Production accepts this value instead of an unconfirmed request.
nonisolated struct ConfirmedSynchronizationPlan: Hashable, Sendable {
    let direction: ProductionSynchronizationDirection
    let plan: SynchronizationPlan
    let planFingerprint: SynchronizationPlanFingerprint
    let sourceSnapshotFingerprint: SynchronizationSnapshotFingerprint
    let targetSnapshotFingerprint: SynchronizationSnapshotFingerprint

    let executionRequest: ProductionSynchronizationRequest

    init(
        confirming preview: SynchronizationPreviewResult,
        executionRequest: ProductionSynchronizationRequest
    ) throws {
        guard preview.request.matches(executionRequest) else {
            throw PlanConfirmationError.requestMismatch
        }
        self.init(
            direction: preview.direction,
            plan: preview.plan,
            planFingerprint: preview.planFingerprint,
            sourceSnapshotFingerprint: preview.sourceSnapshotFingerprint,
            targetSnapshotFingerprint: preview.targetSnapshotFingerprint,
            executionRequest: executionRequest
        )
    }

    init(
        direction: ProductionSynchronizationDirection,
        plan: SynchronizationPlan,
        planFingerprint: SynchronizationPlanFingerprint,
        sourceSnapshotFingerprint: SynchronizationSnapshotFingerprint,
        targetSnapshotFingerprint: SynchronizationSnapshotFingerprint,
        executionRequest: ProductionSynchronizationRequest
    ) {
        self.direction = direction
        self.plan = plan
        self.planFingerprint = planFingerprint
        self.sourceSnapshotFingerprint = sourceSnapshotFingerprint
        self.targetSnapshotFingerprint = targetSnapshotFingerprint
        self.executionRequest = executionRequest
    }

    func validate(against preview: SynchronizationPreviewResult) throws {
        guard direction == preview.direction,
              executionRequest.direction == direction,
              executionRequest.matches(preview.request),
              plan == preview.plan,
              planFingerprint == preview.planFingerprint,
              sourceSnapshotFingerprint == preview.sourceSnapshotFingerprint,
              targetSnapshotFingerprint == preview.targetSnapshotFingerprint,
              planFingerprint == (try PlanConfirmationFingerprinting.plan(plan)) else {
            throw PlanConfirmationError.planChanged
        }
    }
}

nonisolated enum PlanConfirmationFingerprinting {
    static func plan(
        _ plan: SynchronizationPlan
    ) throws -> SynchronizationPlanFingerprint {
        let canonicalPlan = CanonicalPlan(plan)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        do {
            return SynchronizationPlanFingerprint(
                rawValue: digest(try encoder.encode(canonicalPlan))
            )
        } catch {
            throw PlanConfirmationError.fingerprintCreationFailed
        }
    }

    static func snapshot(
        _ snapshot: BSESnapshot
    ) throws -> SynchronizationSnapshotFingerprint {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        do {
            return SynchronizationSnapshotFingerprint(
                rawValue: digest(try encoder.encode(snapshot))
            )
        } catch {
            throw PlanConfirmationError.fingerprintCreationFailed
        }
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map {
            String(format: "%02x", $0)
        }.joined()
    }
}

nonisolated private struct CanonicalPlan: Encodable {
    let phases: [CanonicalPhase]
    let report: CanonicalReport

    init(_ plan: SynchronizationPlan) {
        phases = plan.phases.map(CanonicalPhase.init)
        report = CanonicalReport(plan.report)
    }
}

nonisolated private struct CanonicalPhase: Encodable {
    let kind: String
    let operations: [CanonicalOperation]

    init(_ phase: SynchronizationPhase) {
        switch phase {
        case .preparation(let operations):
            kind = "preparation"
            self.operations = operations.map(CanonicalOperation.init)
        case .structural(let operations):
            kind = "structural"
            self.operations = operations.map(CanonicalOperation.init)
        case .content(let operations):
            kind = "content"
            self.operations = operations.map(CanonicalOperation.init)
        case .cleanup(let operations):
            kind = "cleanup"
            self.operations = operations.map(CanonicalOperation.init)
        }
    }
}

nonisolated private struct CanonicalOperation: Encodable {
    let kind: String
    let logicalNodeID: UUID
    let nodeKind: String?
    let title: String?
    let url: String?
    let parentID: UUID?
    let position: Int?
    let lifecycle: String?

    init(_ operation: SynchronizationOperation) {
        logicalNodeID = operation.logicalNodeID.rawValue
        switch operation {
        case .create(let value):
            kind = "create"
            nodeKind = value.kind.rawValue
            title = value.title
            url = value.url?.absoluteString
            parentID = value.parentID?.rawValue
            position = value.position
            lifecycle = nil
        case .delete:
            kind = "delete"
            nodeKind = nil
            title = nil
            url = nil
            parentID = nil
            position = nil
            lifecycle = nil
        case .rename(let value):
            kind = "rename"
            nodeKind = nil
            title = value.title
            url = nil
            parentID = nil
            position = nil
            lifecycle = nil
        case .updateURL(let value):
            kind = "updateURL"
            nodeKind = nil
            title = nil
            url = value.url.absoluteString
            parentID = nil
            position = nil
            lifecycle = nil
        case .move(let value):
            kind = "move"
            nodeKind = nil
            title = nil
            url = nil
            parentID = value.parentID?.rawValue
            position = value.position
            lifecycle = nil
        case .reorder(let value):
            kind = "reorder"
            nodeKind = nil
            title = nil
            url = nil
            parentID = nil
            position = value.position
            lifecycle = nil
        case .archive(let value):
            kind = "archive"
            nodeKind = nil
            title = nil
            url = nil
            parentID = nil
            position = nil
            lifecycle = value.state.rawValue
        }
    }
}

nonisolated private struct CanonicalReport: Encodable {
    let directionSource: UUID
    let directionTarget: UUID
    let changeSelection: String
    let deletedLifecycleHandling: String
    let inputChangeCount: Int
    let plannedOperationCount: Int
    let skippedChangeCount: Int
    let preparationOperationCount: Int
    let structuralOperationCount: Int
    let contentOperationCount: Int
    let cleanupOperationCount: Int

    init(_ report: SynchronizationPlanningReport) {
        directionSource = report.policy.direction.source.rawValue
        directionTarget = report.policy.direction.target.rawValue
        changeSelection = report.policy.changeSelection.rawValue
        deletedLifecycleHandling = report.policy.deletedLifecycleHandling.rawValue
        inputChangeCount = report.inputChangeCount
        plannedOperationCount = report.plannedOperationCount
        skippedChangeCount = report.skippedChangeCount
        preparationOperationCount = report.preparationOperationCount
        structuralOperationCount = report.structuralOperationCount
        contentOperationCount = report.contentOperationCount
        cleanupOperationCount = report.cleanupOperationCount
    }
}

nonisolated private extension SynchronizationPreviewRequest {
    func matches(_ request: ProductionSynchronizationRequest) -> Bool {
        direction == request.direction
            && safariSourceID == request.safariSourceID
            && chromeSourceID == request.chromeSourceID
            && safariBookmarksURL == request.safariBookmarksURL
            && chromeBookmarksURL == request.chromeBookmarksURL
            && safariSecurityScopeURL
                == request.safariSecurityScopeURL
            && chromeSecurityScopeURL
                == request.chromeSecurityScopeURL
            && chromeProfileIdentifier == request.chromeProfileIdentifier
    }
}

nonisolated private extension ProductionSynchronizationRequest {
    func matches(_ request: SynchronizationPreviewRequest) -> Bool {
        request.matches(self)
    }
}
