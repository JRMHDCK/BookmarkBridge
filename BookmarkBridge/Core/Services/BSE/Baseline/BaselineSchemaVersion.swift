//
//  BaselineSchemaVersion.swift
//  BookmarkBridge
//

/// Explicit version of the serialized baseline schema.
nonisolated struct BaselineSchemaVersion: Hashable, Codable, Sendable, Comparable {
    let rawValue: UInt64

    init(_ rawValue: UInt64) {
        self.rawValue = rawValue
    }

    static let current = BaselineSchemaVersion(1)

    static func < (lhs: BaselineSchemaVersion, rhs: BaselineSchemaVersion) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
