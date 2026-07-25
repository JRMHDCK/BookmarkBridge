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
    let direction: SynchronizationDirection
    let changeSelection: SynchronizationChangeSelection
    let deletedLifecycleHandling: DeletedLifecycleHandling

    init(
        direction: SynchronizationDirection,
        changeSelection: SynchronizationChangeSelection,
        deletedLifecycleHandling: DeletedLifecycleHandling
    ) {
        self.direction = direction
        self.changeSelection = changeSelection
        self.deletedLifecycleHandling = deletedLifecycleHandling
    }

    static func allChanges(
        direction: SynchronizationDirection
    ) -> SynchronizationPolicy {
        SynchronizationPolicy(
            direction: direction,
            changeSelection: .allChanges,
            deletedLifecycleHandling: .delete
        )
    }

    static func additionsOnly(
        direction: SynchronizationDirection
    ) -> SynchronizationPolicy {
        SynchronizationPolicy(
            direction: direction,
            changeSelection: .additionsOnly,
            deletedLifecycleHandling: .reject
        )
    }

    static func contentOnly(
        direction: SynchronizationDirection
    ) -> SynchronizationPolicy {
        SynchronizationPolicy(
            direction: direction,
            changeSelection: .contentOnly,
            deletedLifecycleHandling: .reject
        )
    }
}
