//
//  NativeNodeIdentifier.swift
//  BookmarkBridge
//

/// Opaque source-owned identity. BSE stores and returns the value without
/// interpreting its format or generating it.
nonisolated struct NativeNodeIdentifier: Hashable, Codable, Sendable {
    let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}
