//
//  EndToEndSynchronizationError.swift
//  BookmarkBridge
//

nonisolated struct EndToEndSynchronizationFailureContext:
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

nonisolated enum EndToEndSynchronizationError: Error, Hashable, Sendable {
    case sourceReadFailure(EndToEndSynchronizationFailureContext)
    case targetReadFailure(EndToEndSynchronizationFailureContext)
    case targetRereadFailure(EndToEndSynchronizationFailureContext)
    case matchingFailure(EndToEndSynchronizationFailureContext)
    case bootstrapFailure(EndToEndSynchronizationFailureContext)
    case projectionFailure(EndToEndSynchronizationFailureContext)
    case diffFailure(EndToEndSynchronizationFailureContext)
    case planningFailure(EndToEndSynchronizationFailureContext)
    case executionFailed(SynchronizationExecutionStatus)
    case missingLogicalSnapshot(BSESourceID)
    case residualDiff([LogicalChange])
}
