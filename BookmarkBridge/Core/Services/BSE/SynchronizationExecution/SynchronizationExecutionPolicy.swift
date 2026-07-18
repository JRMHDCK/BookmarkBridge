//
//  SynchronizationExecutionPolicy.swift
//  BookmarkBridge
//

nonisolated enum SynchronizationExecutionPolicy: String, Hashable, Codable, Sendable {
    case stopOnFirstFailure
    case continueAfterFailure
}
