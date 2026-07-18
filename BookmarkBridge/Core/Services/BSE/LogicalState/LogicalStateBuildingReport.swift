//
//  LogicalStateBuildingReport.swift
//  BookmarkBridge
//

/// Deterministic diagnostics that never influence graph construction.
nonisolated struct LogicalStateBuildingReport: Hashable, Codable, Sendable {
    let baselineIdentityCount: Int
    let snapshotCount: Int
    let snapshotNodeCount: Int
    let logicalNodeCount: Int
    let structurallyAvailableNodeCount: Int
    let baselineOnlyNodeCount: Int
    let unregisteredNodeCount: Int
    let observationCount: Int
}
