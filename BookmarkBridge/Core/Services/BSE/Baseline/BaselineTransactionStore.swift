//
//  BaselineTransactionStore.swift
//  BookmarkBridge
//

/// Store capability required only by the global synchronization recovery
/// boundary. Restoration bypasses monotonic save validation deliberately
/// because it reinstates an exact previously persisted value.
nonisolated protocol BaselineTransactionStore: BaselineStore {
    func restoreTransactionSnapshot(_ baseline: Baseline?) async throws
}
