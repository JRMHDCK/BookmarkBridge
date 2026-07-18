//
//  LogicalDiffReport.swift
//  BookmarkBridge
//

/// Deterministic diagnostics that never participate in diff decisions.
nonisolated struct LogicalDiffReport: Hashable, Codable, Sendable {
    let requestedSourceIDs: [BSESourceID]
    let baselineIdentityCount: Int
    let observedIdentityCount: Int
    let createdIdentityCount: Int
    let updatedIdentityCount: Int
    let archivedIdentityCount: Int
    let reactivatedIdentityCount: Int
    let observationChangeCount: Int
    let unchangedIdentityCount: Int
}
