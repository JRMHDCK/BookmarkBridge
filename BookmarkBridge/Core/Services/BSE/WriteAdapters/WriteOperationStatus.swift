//
//  WriteOperationStatus.swift
//  BookmarkBridge
//

nonisolated enum WriteOperationStatus: String, Hashable, Codable, Sendable {
    case applied
    case alreadySatisfied
    case simulated
}
