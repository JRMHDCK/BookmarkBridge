//
//  IdentityReconciliationReport.swift
//  BookmarkBridge
//

nonisolated struct CreatedIdentityReport: Hashable, Codable, Sendable {
    let logicalNodeID: LogicalNodeID
    let members: [IdentityNodeReference]
}

nonisolated struct ReusedIdentityReport: Hashable, Codable, Sendable {
    let logicalNodeID: LogicalNodeID
    let members: [IdentityNodeReference]
}

nonisolated struct IdentityAmbiguityReport: Hashable, Codable, Sendable {
    let members: [IdentityNodeReference]
    let candidateIDs: [LogicalNodeID]
}

nonisolated enum IdentityReconciliationDiagnostic: Hashable, Codable, Sendable {
    case snapshotIncomplete(sourceID: BSESourceID)
    case unmatchedNode(IdentityNodeReference)
}

nonisolated struct IdentityReconciliationStatistics: Hashable, Codable, Sendable {
    let snapshotCount: Int
    let logicalSnapshotCount: Int
    let groupCount: Int
    let createdIdentityCount: Int
    let reusedIdentityCount: Int
    let ambiguityCount: Int
    let unresolvedObjectCount: Int
    let baselineCommandCount: Int
}

/// Diagnostics are observational only and never feed policy or engine decisions.
nonisolated struct IdentityReconciliationReport: Hashable, Codable, Sendable {
    let createdIdentities: [CreatedIdentityReport]
    let reusedIdentities: [ReusedIdentityReport]
    let ambiguities: [IdentityAmbiguityReport]
    let unresolvedObjects: [IdentityNodeReference]
    let diagnostics: [IdentityReconciliationDiagnostic]
    let statistics: IdentityReconciliationStatistics
}
