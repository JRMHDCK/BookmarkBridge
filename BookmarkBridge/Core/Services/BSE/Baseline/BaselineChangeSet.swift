//
//  BaselineChangeSet.swift
//  BookmarkBridge
//

/// Complete deterministic result of one pure batch application.
nonisolated struct BaselineChangeSet: Hashable, Sendable {
    let baseline: Baseline
    let createdIdentities: [LogicalNodeID]
    let modifiedIdentities: [LogicalNodeID]
    let revisionBefore: BaselineRevision
    let revisionAfter: BaselineRevision
    let executedCommands: [BaselineCommand]
}
