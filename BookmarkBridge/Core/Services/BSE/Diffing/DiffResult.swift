//
//  DiffResult.swift
//  BookmarkBridge
//

/// One atomic BSE event paired with the observed reason that produced it.
nonisolated struct DiffEntry: Hashable, Codable, Sendable {
    let event: BSEEvent
    let reason: DiffReason

    init(event: BSEEvent, reason: DiffReason) {
        self.event = event
        self.reason = reason
    }
}

/// The deterministic, explained differences between exactly two snapshots.
nonisolated struct DiffResult: Hashable, Codable, Sendable {
    let entries: [DiffEntry]

    init(entries: [DiffEntry]) {
        self.entries = entries
    }

    var events: [BSEEvent] { entries.map(\.event) }
    var isEmpty: Bool { entries.isEmpty }
}
