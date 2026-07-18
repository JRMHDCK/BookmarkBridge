//
//  BSESnapshot.swift
//  BookmarkBridge
//

import Foundation

/// An immutable capture of one logical source at a precise instant.
nonisolated struct BSESnapshot: Hashable, Codable, Sendable {
    let source: BSESourceID
    let capturedAt: Date
    let tree: BSETree

    init(source: BSESourceID, capturedAt: Date, tree: BSETree) {
        self.source = source
        self.capturedAt = capturedAt
        self.tree = tree
    }
}
