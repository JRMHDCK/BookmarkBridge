//
//  BSEIdentifiers.swift
//  BookmarkBridge
//

import Foundation

/// Stable identity of a logical node tracked by BSE, independent of any
/// browser-specific identifier.
nonisolated struct LogicalNodeID: Hashable, Codable, Sendable, Comparable, CustomStringConvertible {
    let rawValue: UUID

    init(_ rawValue: UUID) {
        self.rawValue = rawValue
    }

    static func < (lhs: LogicalNodeID, rhs: LogicalNodeID) -> Bool {
        lhs.rawValue.uuidString < rhs.rawValue.uuidString
    }

    var description: String { rawValue.uuidString }
}

/// Stable identity of a logical source observed by BSE.
///
/// The identifier deliberately carries no Safari, Chrome, profile, or file
/// semantics. Adapters introduced later will map concrete sources to this value.
nonisolated struct BSESourceID: Hashable, Codable, Sendable, CustomStringConvertible {
    let rawValue: UUID

    init(_ rawValue: UUID) {
        self.rawValue = rawValue
    }

    var description: String { rawValue.uuidString }
}
