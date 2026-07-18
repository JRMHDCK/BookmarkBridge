//
//  ConflictResult.swift
//  BookmarkBridge
//

/// Deterministic conflict resolutions ordered by `LogicalNodeID`.
nonisolated struct ConflictResult: Hashable, Codable, Sendable {
    let resolutions: [ConflictResolution]

    init(resolutions: [ConflictResolution]) {
        self.resolutions = resolutions
    }

    var isEmpty: Bool { resolutions.isEmpty }
}
