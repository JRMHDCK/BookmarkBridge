//
//  IdentityProvider.swift
//  BookmarkBridge
//

/// Explicit source of durable identities. The reconciliation engine never
/// creates UUIDs or otherwise invents identifiers itself.
nonisolated protocol IdentityProvider: Sendable {
    func nextLogicalNodeID() throws -> LogicalNodeID
}
