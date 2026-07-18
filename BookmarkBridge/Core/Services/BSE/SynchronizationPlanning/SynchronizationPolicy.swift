//
//  SynchronizationPolicy.swift
//  BookmarkBridge
//

nonisolated enum SynchronizationChangeSelection: String, Hashable, Sendable {
    case allChanges
    case additionsOnly
    case contentOnly
}

nonisolated enum DeletedLifecycleHandling: String, Hashable, Sendable {
    case delete
    case archive
    case reject
}

/// Immutable, explicit decisions applied without interpretation by the Planner.
nonisolated struct SynchronizationPolicy: Hashable, Sendable {
    let changeSelection: SynchronizationChangeSelection
    let deletedLifecycleHandling: DeletedLifecycleHandling

    init(
        changeSelection: SynchronizationChangeSelection,
        deletedLifecycleHandling: DeletedLifecycleHandling
    ) {
        self.changeSelection = changeSelection
        self.deletedLifecycleHandling = deletedLifecycleHandling
    }

    static let allChanges = SynchronizationPolicy(
        changeSelection: .allChanges,
        deletedLifecycleHandling: .delete
    )

    static let additionsOnly = SynchronizationPolicy(
        changeSelection: .additionsOnly,
        deletedLifecycleHandling: .reject
    )

    static let contentOnly = SynchronizationPolicy(
        changeSelection: .contentOnly,
        deletedLifecycleHandling: .reject
    )
}
