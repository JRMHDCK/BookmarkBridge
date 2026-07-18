//
//  WriteExecutionContext.swift
//  BookmarkBridge
//

nonisolated enum WriteExecutionMode: String, Hashable, Codable, Sendable {
    case dryRun
    case apply
}

/// Explicit inputs shared by one atomic adapter invocation.
nonisolated struct WriteExecutionContext: Hashable, Codable, Sendable {
    let sourceID: BSESourceID
    let mode: WriteExecutionMode
}
