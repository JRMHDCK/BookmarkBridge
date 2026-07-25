//
//  BaselineError.swift
//  BookmarkBridge
//

nonisolated enum BaselineInvariantViolation: String, Hashable, Codable, Sendable {
    case duplicateLogicalNodeID
    case duplicateObservationSource
    case invalidObservationInterval
    case invalidIdentityRevision
    case invalidIdentityMetadata
    case identityRevisionBeyondBaseline
    case baselineIDChanged
    case nonMonotoneRevision
    case revisionOverflow
    case invalidMigrationResult
}

nonisolated enum BaselineError: Error, Hashable, Sendable {
    case identityAlreadyExists(LogicalNodeID)
    case identityNotFound(LogicalNodeID)
    case revisionConflict(expected: BaselineRevision, actual: BaselineRevision)
    case identityRevisionConflict(
        logicalNodeID: LogicalNodeID,
        expected: IdentityRevision,
        actual: IdentityRevision
    )
    case observationNotFound(logicalNodeID: LogicalNodeID, sourceID: BSESourceID)
    case duplicateObservation(logicalNodeID: LogicalNodeID, sourceID: BSESourceID)
    case invalidLifecycleTransition(
        logicalNodeID: LogicalNodeID,
        from: IdentityRecordState,
        to: IdentityRecordState
    )
    case invariantViolation(BaselineInvariantViolation)
    case baselineNotFound
    case baselineAlreadyExists
    case migrationRequired(
        current: BaselineSchemaVersion,
        required: BaselineSchemaVersion
    )
    case migrationPathNotFound(
        from: BaselineSchemaVersion,
        to: BaselineSchemaVersion
    )
    case corruptedData
    case storeFailure
    case transactionUnsupported
}
