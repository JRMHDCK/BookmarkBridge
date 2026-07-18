//
//  DiffReason.swift
//  BookmarkBridge
//

/// The observed fact that caused one atomic BSE diff event.
nonisolated enum DiffReason: Hashable, Codable, Sendable {
    case createdInAfterSnapshot
    case missingFromAfterSnapshot
    case parentChanged
    case positionChanged
    case parentAndPositionChanged
    case titleChanged
    case bookmarkURLChanged
}
