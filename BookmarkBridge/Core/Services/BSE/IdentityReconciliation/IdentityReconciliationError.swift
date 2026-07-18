//
//  IdentityReconciliationError.swift
//  BookmarkBridge
//

nonisolated enum IdentityReconciliationError: Error, Hashable, Sendable {
    case emptyMatchingGroup
    case duplicateSnapshotSource(BSESourceID)
    case duplicateGroupMember(IdentityNodeReference)
    case multipleMembersForSource(BSESourceID)
    case unknownNodeReference(IdentityNodeReference)
    case incompleteAssignments(BSESourceID)
    case assignmentSourceMismatch(BSESourceID)
    case duplicateAssignment(IdentityNodeReference)
    case duplicateLogicalIdentity(BSESourceID)
    case identityCollision(LogicalNodeID)
    case reusedIdentityNotFound(LogicalNodeID)
    case observationTimeRegression(IdentityNodeReference)
    case invalidLogicalSnapshot(BSESourceID)
}
