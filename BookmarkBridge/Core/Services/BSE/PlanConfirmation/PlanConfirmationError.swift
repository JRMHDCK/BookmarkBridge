//
//  PlanConfirmationError.swift
//  BookmarkBridge
//

nonisolated enum PlanConfirmationError: Error, Hashable, Sendable {
    case requestMismatch
    case fingerprintCreationFailed
    case planChanged
}
