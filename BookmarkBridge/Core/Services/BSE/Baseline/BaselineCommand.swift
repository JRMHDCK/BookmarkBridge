//
//  BaselineCommand.swift
//  BookmarkBridge
//

nonisolated struct CreateIdentityCommand: Hashable, Codable, Sendable {
    let logicalNodeID: LogicalNodeID
    let observations: [BaselineObservation]
}

nonisolated struct UpdateObservationCommand: Hashable, Codable, Sendable {
    let logicalNodeID: LogicalNodeID
    let expectedIdentityRevision: IdentityRevision
    let observation: BaselineObservation
}

nonisolated struct ReplaceRecognitionArtifactsCommand: Hashable, Codable, Sendable {
    let logicalNodeID: LogicalNodeID
    let expectedIdentityRevision: IdentityRevision
    let sourceID: BSESourceID
    let recognitionArtifacts: [RecognitionArtifact]
}

nonisolated struct ArchiveIdentityCommand: Hashable, Codable, Sendable {
    let logicalNodeID: LogicalNodeID
    let expectedIdentityRevision: IdentityRevision
}

nonisolated struct MarkIdentityDeletedCommand: Hashable, Codable, Sendable {
    let logicalNodeID: LogicalNodeID
    let expectedIdentityRevision: IdentityRevision
}

nonisolated struct ReactivateIdentityCommand: Hashable, Codable, Sendable {
    let logicalNodeID: LogicalNodeID
    let expectedIdentityRevision: IdentityRevision
}

/// Closed set of typed mutations understood by the baseline engine.
nonisolated enum BaselineCommand: Hashable, Codable, Sendable {
    case createIdentity(CreateIdentityCommand)
    case updateObservation(UpdateObservationCommand)
    case replaceRecognitionArtifacts(ReplaceRecognitionArtifactsCommand)
    case archiveIdentity(ArchiveIdentityCommand)
    case markIdentityDeleted(MarkIdentityDeletedCommand)
    case reactivateIdentity(ReactivateIdentityCommand)
}
