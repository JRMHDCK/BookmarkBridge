//
//  ChromeBookmarkMutationError.swift
//  BookmarkBridge
//

nonisolated enum ChromeBookmarkMutationError: Error, Hashable, Sendable {
    case invalidDocument
    case missingNativeIdentifier
    case duplicateNativeIdentifier(String)
    case nativeIdentityMissing(LogicalNodeID)
    case nativeIdentityAlreadyExists(LogicalNodeID)
    case nativeNodeNotFound(NativeNodeIdentifier)
    case parentNotFound(LogicalNodeID)
    case parentIsNotFolder(NativeNodeIdentifier)
    case invalidPosition(Int)
    case invalidCreateOperation(LogicalNodeID)
    case nonEmptyFolder(LogicalNodeID)
    case cannotMutatePermanentRoot(LogicalNodeID)
    case rootDestinationUnsupported
    case cycleDetected(LogicalNodeID)
    case URLUpdateRequiresBookmark(LogicalNodeID)
    case nativeIdentifierGenerationFailed
    case unsupportedOperation(LogicalNodeID)
    case serializationFailed
}
