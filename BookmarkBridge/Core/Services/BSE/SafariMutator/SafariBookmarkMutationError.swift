//
//  SafariBookmarkMutationError.swift
//  BookmarkBridge
//

nonisolated enum SafariBookmarkMutationError: Error, Hashable, Sendable {
    case invalidDocument
    case missingUUID
    case duplicateUUID(String)
    case nativeIdentityMissing(LogicalNodeID)
    case nativeIdentityAlreadyExists(LogicalNodeID)
    case nativeNodeNotFound(NativeNodeIdentifier)
    case parentNotFound(LogicalNodeID)
    case parentIsNotFolder(NativeNodeIdentifier)
    case invalidPosition(Int)
    case invalidCreateOperation(LogicalNodeID)
    case nonEmptyFolder(LogicalNodeID)
    case cannotMutateRoot(LogicalNodeID)
    case cycleDetected(LogicalNodeID)
    case URLUpdateRequiresBookmark(LogicalNodeID)
    case nativeIdentifierGenerationFailed
    case unsupportedOperation(LogicalNodeID)
    case serializationFailed
}
