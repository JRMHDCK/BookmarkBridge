//
//  BSEAdapterRestorePoint.swift
//  BookmarkBridge
//

import Foundation

/// Opaque identity of adapter-private restore data.
nonisolated struct BSEAdapterRestorePointID: Hashable, Codable, Sendable, CustomStringConvertible {
    let rawValue: UUID

    init(_ rawValue: UUID) {
        self.rawValue = rawValue
    }

    var description: String { rawValue.uuidString }
}

/// Universal metadata for a restore point whose native payload stays private
/// to the adapter implementation.
nonisolated struct BSEAdapterRestorePoint: Hashable, Codable, Sendable {
    let restorePointID: BSEAdapterRestorePointID
    let sourceID: BSESourceID

    init(
        restorePointID: BSEAdapterRestorePointID,
        sourceID: BSESourceID
    ) {
        self.restorePointID = restorePointID
        self.sourceID = sourceID
    }
}
