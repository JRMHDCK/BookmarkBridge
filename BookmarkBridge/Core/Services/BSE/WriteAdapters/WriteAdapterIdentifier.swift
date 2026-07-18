//
//  WriteAdapterIdentifier.swift
//  BookmarkBridge
//

import Foundation

/// Opaque identity supplied by composition code; the contract never generates it.
nonisolated struct WriteAdapterIdentifier: Hashable, Codable, Sendable, CustomStringConvertible {
    let rawValue: UUID

    init(_ rawValue: UUID) {
        self.rawValue = rawValue
    }

    var description: String { rawValue.uuidString }
}
