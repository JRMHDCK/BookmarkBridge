//
//  ChromePersistenceError.swift
//  BookmarkBridge
//

nonisolated enum ChromeBookmarkStructureViolation: Error, Hashable, Sendable {
    case rootsMissing
    case invalidRoots
    case invalidRoot(key: String)
    case invalidNode(path: [String])
    case missingIdentifier(path: [String])
    case duplicateIdentifier(String)
    case duplicateGUID(String)
    case invalidGUID(path: [String])
    case invalidName(path: [String])
    case invalidChildren(path: [String])
    case invalidURL(path: [String])
    case unknownNodeType(path: [String])
    case invalidVersion
    case invalidChecksum
}

nonisolated enum ChromePersistenceError: Error, Hashable, Sendable {
    case chromeIsOpen
    case fileMissing
    case accessDenied
    case invalidJSON
    case invalidStructure(ChromeBookmarkStructureViolation)
    case backupFailed
    case backupCollision
    case invalidFingerprint
    case concurrentModification
    case temporaryWriteFailed
    case synchronizationFailed
    case atomicReplacementFailed
}
