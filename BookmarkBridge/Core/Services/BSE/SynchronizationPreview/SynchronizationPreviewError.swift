//
//  SynchronizationPreviewError.swift
//  BookmarkBridge
//

nonisolated struct SynchronizationPreviewFailureContext:
    Hashable,
    Sendable
{
    let errorType: String
    let description: String

    init(_ error: any Error) {
        errorType = String(reflecting: type(of: error))
        description = String(describing: error)
    }

    init(_ context: SynchronizationPipelineFailureContext) {
        errorType = context.errorType
        description = context.description
    }
}

nonisolated enum SynchronizationPreviewError: Error, Hashable, Sendable {
    case sourceReadFailure(SynchronizationPreviewFailureContext)
    case targetReadFailure(SynchronizationPreviewFailureContext)
    case matchingFailure(SynchronizationPreviewFailureContext)
    case bootstrapFailure(SynchronizationPreviewFailureContext)
    case missingLogicalSnapshot(BSESourceID)
    case projectionFailure(SynchronizationPreviewFailureContext)
    case diffFailure(SynchronizationPreviewFailureContext)
    case planningFailure(SynchronizationPreviewFailureContext)
    case suspiciousStructuralChurn(
        movedCount: Int,
        equivalentPathMoveCount: Int
    )
}
