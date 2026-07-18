//
//  SynchronizationExecutionStatus.swift
//  BookmarkBridge
//

nonisolated enum SynchronizationExecutionStatus: String, Hashable, Codable, Sendable {
    case completed
    case completedWithFailures
    case stoppedOnFailure
    case cancelled
}
