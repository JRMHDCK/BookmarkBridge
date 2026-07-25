//
//  SynchronizationPipelineError.swift
//  BookmarkBridge
//

nonisolated struct SynchronizationPipelineFailureContext:
    Hashable,
    Sendable
{
    let errorType: String
    let description: String

    init(_ error: any Error) {
        errorType = String(reflecting: type(of: error))
        description = String(describing: error)
    }
}

nonisolated enum SynchronizationPipelineError: Error, Hashable, Sendable {
    case sourceReadFailure(SynchronizationPipelineFailureContext)
    case targetReadFailure(SynchronizationPipelineFailureContext)
    case nativeIdentityResolutionFailure(
        SynchronizationPipelineFailureContext
    )
    case matchingFailure(SynchronizationPipelineFailureContext)
    case bootstrapFailure(SynchronizationPipelineFailureContext)
    case missingLogicalSnapshot(BSESourceID)
    case projectionFailure(SynchronizationPipelineFailureContext)
    case diffFailure(SynchronizationPipelineFailureContext)
    case planningFailure(SynchronizationPipelineFailureContext)
}
