//
//  BaselineID.swift
//  BookmarkBridge
//

import Foundation

/// Stable identity of one baseline registry. It is always supplied explicitly.
nonisolated struct BaselineID: Hashable, Codable, Sendable, CustomStringConvertible {
    let rawValue: UUID

    init(_ rawValue: UUID) {
        self.rawValue = rawValue
    }

    var description: String { rawValue.uuidString }
}

/// Monotone revision of an entire baseline.
nonisolated struct BaselineRevision: Hashable, Codable, Sendable, Comparable {
    let rawValue: UInt64

    init(_ rawValue: UInt64) {
        self.rawValue = rawValue
    }

    static let zero = BaselineRevision(0)

    static func < (lhs: BaselineRevision, rhs: BaselineRevision) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    func incremented() throws -> BaselineRevision {
        guard rawValue < UInt64.max else {
            throw BaselineError.invariantViolation(.revisionOverflow)
        }
        return BaselineRevision(rawValue + 1)
    }
}

/// Monotone revision of one durable logical identity.
nonisolated struct IdentityRevision: Hashable, Codable, Sendable, Comparable {
    let rawValue: UInt64

    init(_ rawValue: UInt64) throws {
        guard rawValue > 0 else {
            throw BaselineError.invariantViolation(.invalidIdentityRevision)
        }
        self.rawValue = rawValue
    }

    static func < (lhs: IdentityRevision, rhs: IdentityRevision) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    func incremented() throws -> IdentityRevision {
        guard rawValue < UInt64.max else {
            throw BaselineError.invariantViolation(.revisionOverflow)
        }
        return try IdentityRevision(rawValue + 1)
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(UInt64.self)
        do {
            try self.init(value)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Identity revision must be greater than zero"
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
