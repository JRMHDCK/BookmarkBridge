//
//  ProductionSynchronizationError.swift
//  BookmarkBridge
//

nonisolated struct ProductionSynchronizationFailureContext:
    Hashable,
    Sendable
{
    let errorType: String
    let description: String

    init(_ error: any Error) {
        errorType = String(reflecting: type(of: error))
        description = String(describing: error)
    }
}

nonisolated enum ProductionSynchronizationError: Error, Hashable, Sendable {
    case unsupportedDirection(ProductionSynchronizationDirection)
    case synchronizationFailed(ProductionSynchronizationFailureContext)
}
