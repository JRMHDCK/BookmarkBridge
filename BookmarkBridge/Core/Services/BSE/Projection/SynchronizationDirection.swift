//
//  SynchronizationDirection.swift
//  BookmarkBridge
//

/// Explicit source authority for a synchronization projection.
/// Bidirectional synchronization is intentionally not represented yet.
nonisolated enum SynchronizationDirection: Hashable, Sendable {
    case oneWay(source: BSESourceID, target: BSESourceID)

    var source: BSESourceID {
        switch self {
        case .oneWay(let source, _): source
        }
    }

    var target: BSESourceID {
        switch self {
        case .oneWay(_, let target): target
        }
    }
}
