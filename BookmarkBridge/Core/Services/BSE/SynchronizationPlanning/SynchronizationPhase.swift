//
//  SynchronizationPhase.swift
//  BookmarkBridge
//

nonisolated enum SynchronizationPhase: Hashable, Sendable {
    case preparation([SynchronizationOperation])
    case structural([SynchronizationOperation])
    case content([SynchronizationOperation])
    case cleanup([SynchronizationOperation])

    var operations: [SynchronizationOperation] {
        switch self {
        case .preparation(let operations),
             .structural(let operations),
             .content(let operations),
             .cleanup(let operations):
            operations
        }
    }
}
