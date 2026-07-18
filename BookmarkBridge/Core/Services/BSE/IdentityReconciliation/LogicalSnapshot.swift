//
//  LogicalSnapshot.swift
//  BookmarkBridge
//

import Foundation

/// Immutable snapshot whose tree uses durable BSE logical identities.
nonisolated struct LogicalSnapshot: Hashable, Codable, Sendable {
    let source: BSESourceID
    let capturedAt: Date
    let tree: BSETree
}

/// Mechanical mapping from one source-local provisional key to a durable ID.
nonisolated struct LogicalIdentityAssignment: Hashable, Codable, Sendable {
    let sourceID: BSESourceID
    let provisionalLogicalID: LogicalNodeID
    let logicalNodeID: LogicalNodeID
}
