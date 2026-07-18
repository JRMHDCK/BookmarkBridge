//
//  BSEAdapterCapabilities.swift
//  BookmarkBridge
//

/// A typed capability used in validation errors.
nonisolated enum BSEAdapterCapability: String, Hashable, Codable, Sendable {
    case read
    case write
    case create
    case delete
    case move
    case rename
    case verify
    case createRestorePoint
    case restore
}

/// Immutable declaration of every operation an adapter can perform.
nonisolated struct BSEAdapterCapabilities: Hashable, Codable, Sendable {
    let canRead: Bool
    let canWrite: Bool
    let canCreate: Bool
    let canDelete: Bool
    let canMove: Bool
    let canRename: Bool
    let canVerify: Bool
    let canCreateRestorePoint: Bool
    let canRestore: Bool

    init(
        canRead: Bool,
        canWrite: Bool,
        canCreate: Bool,
        canDelete: Bool,
        canMove: Bool,
        canRename: Bool,
        canVerify: Bool,
        canCreateRestorePoint: Bool,
        canRestore: Bool
    ) {
        self.canRead = canRead
        self.canWrite = canWrite
        self.canCreate = canCreate
        self.canDelete = canDelete
        self.canMove = canMove
        self.canRename = canRename
        self.canVerify = canVerify
        self.canCreateRestorePoint = canCreateRestorePoint
        self.canRestore = canRestore
    }

    func supports(_ capability: BSEAdapterCapability) -> Bool {
        switch capability {
        case .read: canRead
        case .write: canWrite
        case .create: canCreate
        case .delete: canDelete
        case .move: canMove
        case .rename: canRename
        case .verify: canVerify
        case .createRestorePoint: canCreateRestorePoint
        case .restore: canRestore
        }
    }
}
