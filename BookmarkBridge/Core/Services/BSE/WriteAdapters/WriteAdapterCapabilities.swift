//
//  WriteAdapterCapabilities.swift
//  BookmarkBridge
//

nonisolated enum WriteOperationKind: String, Hashable, Codable, Sendable {
    case create
    case delete
    case rename
    case updateURL
    case move
    case reorder
    case archive
}

nonisolated enum WriteAdapterCapability: String, Hashable, Codable, Sendable {
    case create
    case delete
    case rename
    case updateURL
    case move
    case reorder
    case archive
    case dryRun
}

/// Immutable declaration of every write behavior exposed by an adapter.
nonisolated struct WriteAdapterCapabilities: Hashable, Codable, Sendable {
    let canCreate: Bool
    let canDelete: Bool
    let canRename: Bool
    let canUpdateURL: Bool
    let canMove: Bool
    let canReorder: Bool
    let canArchive: Bool
    let canDryRun: Bool

    init(
        canCreate: Bool,
        canDelete: Bool,
        canRename: Bool,
        canUpdateURL: Bool,
        canMove: Bool,
        canReorder: Bool,
        canArchive: Bool,
        canDryRun: Bool
    ) {
        self.canCreate = canCreate
        self.canDelete = canDelete
        self.canRename = canRename
        self.canUpdateURL = canUpdateURL
        self.canMove = canMove
        self.canReorder = canReorder
        self.canArchive = canArchive
        self.canDryRun = canDryRun
    }

    func supports(_ capability: WriteAdapterCapability) -> Bool {
        switch capability {
        case .create: canCreate
        case .delete: canDelete
        case .rename: canRename
        case .updateURL: canUpdateURL
        case .move: canMove
        case .reorder: canReorder
        case .archive: canArchive
        case .dryRun: canDryRun
        }
    }

    func supports(_ operation: SynchronizationOperation) -> Bool {
        supports(operation.requiredWriteCapability)
    }
}

nonisolated extension SynchronizationOperation {
    var writeOperationKind: WriteOperationKind {
        switch self {
        case .create: .create
        case .delete: .delete
        case .rename: .rename
        case .updateURL: .updateURL
        case .move: .move
        case .reorder: .reorder
        case .archive: .archive
        }
    }

    var requiredWriteCapability: WriteAdapterCapability {
        switch self {
        case .create: .create
        case .delete: .delete
        case .rename: .rename
        case .updateURL: .updateURL
        case .move: .move
        case .reorder: .reorder
        case .archive: .archive
        }
    }
}
