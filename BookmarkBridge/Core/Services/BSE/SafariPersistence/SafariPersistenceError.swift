//
//  SafariPersistenceError.swift
//  BookmarkBridge
//

import Foundation

nonisolated enum SafariBookmarkStructureViolation: Error, Hashable, Sendable {
    case rootIsNotDictionary
    case unrecognizedRoot
    case missingUUID(path: [Int])
    case duplicateUUID(String)
    case invalidNode(path: [Int])
    case invalidChildren(path: [Int])
    case invalidTitle(path: [Int])
    case invalidURL(path: [Int])
    case invalidURIDictionary(path: [Int])
}

nonisolated enum SafariPersistenceError: Error, Hashable, Sendable {
    case safariIsOpen
    case fileMissing
    case accessDenied
    case invalidPropertyList
    case invalidStructure(SafariBookmarkStructureViolation)
    case backupFailed
    case invalidFingerprint
    case concurrentModification
    case temporaryWriteFailed
    case atomicReplacementFailed
}
