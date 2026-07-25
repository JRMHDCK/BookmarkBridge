//
//  ProductionSynchronizationResult.swift
//  BookmarkBridge
//

nonisolated struct ProductionSynchronizationResult: Hashable, Sendable {
    let direction: ProductionSynchronizationDirection
    let synchronization: EndToEndSynchronizationResult
    let transaction: SynchronizationTransactionResult
}
