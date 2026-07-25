//
//  SynchronizationTransactionResult.swift
//  BookmarkBridge
//

nonisolated enum SynchronizationRestorationStatus:
    String,
    Hashable,
    Codable,
    Sendable
{
    case notRequired
    case succeeded
    case failed
}

/// Successful global transaction trace. A nil backup means the confirmed plan
/// was empty, so no write and therefore no recovery point was necessary.
nonisolated struct SynchronizationTransactionResult: Hashable, Sendable {
    let appliedOperationCount: Int
    let backup: SynchronizationBackup?
    let restorationStatus: SynchronizationRestorationStatus
}
