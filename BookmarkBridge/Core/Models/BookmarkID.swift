//
//  BookmarkID.swift
//  BookmarkBridge
//

import Foundation

/// A stable identifier for a bookmark or folder within a tree.
///
/// Wrapping the raw string keeps the domain strongly typed and prevents
/// "stringly-typed" mistakes where an arbitrary string is passed as an id.
nonisolated struct BookmarkID: Hashable, Sendable, Codable, CustomStringConvertible {
    let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    var description: String { rawValue }
}
