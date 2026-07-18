//
//  IdentityReconciliationResult.swift
//  BookmarkBridge
//

nonisolated struct IdentityReconciliationResult: Hashable, Sendable {
    let logicalSnapshots: [LogicalSnapshot]
    let baselineCommands: [BaselineCommand]
    let report: IdentityReconciliationReport
}
