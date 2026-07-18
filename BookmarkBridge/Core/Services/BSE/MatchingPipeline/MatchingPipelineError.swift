//
//  MatchingPipelineError.swift
//  BookmarkBridge
//

/// Serializable description of an injected dependency failure. Pipeline error
/// cases remain the stable, typed discriminator; text is diagnostic only.
nonisolated struct MatchingPipelineFailureContext: Hashable, Codable, Sendable {
    let errorType: String
    let description: String

    init(_ error: any Error) {
        errorType = String(reflecting: type(of: error))
        description = String(describing: error)
    }
}

nonisolated enum MatchingPipelineError: Error, Hashable, Sendable {
    case baselineNotFound
    case duplicateSnapshotSource(BSESourceID)
    case baselineLoadFailure(MatchingPipelineFailureContext)
    case matchingFailure(MatchingPipelineFailureContext)
    case identityReconciliationFailure(MatchingPipelineFailureContext)
    case baselineRevisionConflict(
        expected: BaselineRevision,
        actual: BaselineRevision
    )
    case baselineTransactionFailure(MatchingPipelineFailureContext)
}
