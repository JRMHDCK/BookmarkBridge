//
//  InMemoryNativeIdentityRepository.swift
//  BookmarkBridge
//

import Synchronization

/// Process-local repository for tests and ephemeral composition. `Mutex`
/// preserves the synchronous contract while making every access race-free.
nonisolated final class InMemoryNativeIdentityRepository: NativeIdentityRepository {
    private let storage: Mutex<[MappingKey: NativeNodeIdentifier]>

    init(mappings: [NativeIdentityMapping] = []) {
        storage = Mutex(Dictionary(
            mappings.map {
                (MappingKey(
                    logicalNodeID: $0.logicalNodeID,
                    sourceID: $0.sourceID
                ), $0.nativeIdentifier)
            },
            uniquingKeysWith: { _, latest in latest }
        ))
    }

    func nativeIdentifier(
        for logicalNodeID: LogicalNodeID,
        sourceID: BSESourceID
    ) -> NativeNodeIdentifier? {
        storage.withLock {
            $0[MappingKey(logicalNodeID: logicalNodeID, sourceID: sourceID)]
        }
    }

    func register(_ mapping: NativeIdentityMapping) {
        storage.withLock {
            $0[MappingKey(
                logicalNodeID: mapping.logicalNodeID,
                sourceID: mapping.sourceID
            )] = mapping.nativeIdentifier
        }
    }

    func remove(
        logicalNodeID: LogicalNodeID,
        sourceID: BSESourceID
    ) {
        _ = storage.withLock {
            $0.removeValue(forKey: MappingKey(
                logicalNodeID: logicalNodeID,
                sourceID: sourceID
            ))
        }
    }
}

nonisolated private struct MappingKey: Hashable, Sendable {
    let logicalNodeID: LogicalNodeID
    let sourceID: BSESourceID
}
