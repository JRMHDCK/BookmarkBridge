//
//  ChromeBookmarkWriteAdapter.swift
//  BookmarkBridge
//

import Foundation

/// Persistence seam used only to keep adapter orchestration independently testable.
nonisolated protocol ChromeBookmarkStoring: Sendable {
    func load() throws -> ChromeBookmarkDocument

    @discardableResult
    func save(_ document: ChromeBookmarkDocument) throws -> URL
}

/// Mutation seam used only to verify orchestration without duplicating mutation logic.
nonisolated protocol ChromeBookmarkMutating: Sendable {
    func apply(
        _ operation: SynchronizationOperation,
        to document: ChromeBookmarkDocument
    ) throws -> ChromeBookmarkMutationResult
}

extension ChromeBookmarkStore: ChromeBookmarkStoring {}
extension ChromeBookmarkMutator: ChromeBookmarkMutating {}

/// Executes exactly one Chrome write by composing persistence and in-memory
/// mutation. Deferred native-identity changes are committed only after save.
nonisolated struct ChromeBookmarkWriteAdapter: BookmarkWriteAdapter {
    let identifier: WriteAdapterIdentifier
    let capabilities = WriteAdapterCapabilities(
        canCreate: true,
        canDelete: true,
        canRename: true,
        canUpdateURL: true,
        canMove: true,
        canReorder: true,
        canArchive: false,
        canDryRun: true
    )

    private let sourceID: BSESourceID
    private let store: any ChromeBookmarkStoring
    private let mutator: any ChromeBookmarkMutating
    private let nativeIdentityRepository: any NativeIdentityRepository

    init(
        identifier: WriteAdapterIdentifier,
        sourceID: BSESourceID,
        store: ChromeBookmarkStore,
        mutator: ChromeBookmarkMutator,
        nativeIdentityRepository: any NativeIdentityRepository
    ) {
        self.init(
            identifier: identifier,
            sourceID: sourceID,
            store: store as any ChromeBookmarkStoring,
            mutator: mutator as any ChromeBookmarkMutating,
            nativeIdentityRepository: nativeIdentityRepository
        )
    }

    init(
        identifier: WriteAdapterIdentifier,
        sourceID: BSESourceID,
        store: any ChromeBookmarkStoring,
        mutator: any ChromeBookmarkMutating,
        nativeIdentityRepository: any NativeIdentityRepository
    ) {
        self.identifier = identifier
        self.sourceID = sourceID
        self.store = store
        self.mutator = mutator
        self.nativeIdentityRepository = nativeIdentityRepository
    }

    func execute(
        operation: SynchronizationOperation,
        context: WriteExecutionContext
    ) async throws -> WriteOperationResult {
        guard context.sourceID == sourceID else {
            throw WriteAdapterError.sourceMismatch(
                expected: sourceID,
                actual: context.sourceID
            )
        }
        guard capabilities.supports(operation) else {
            throw WriteAdapterError.unsupportedCapability(
                operation.requiredWriteCapability
            )
        }

        let document = try store.load()
        let mutationResult = try mutator.apply(operation, to: document)

        if context.mode == .dryRun {
            return result(for: operation, status: .simulated)
        }

        // The persistence layer retains the mandatory backup. The generic
        // adapter result intentionally has no browser-specific backup field.
        _ = try store.save(mutationResult.document)
        apply(mutationResult.nativeIdentityChanges)

        return result(for: operation, status: .applied)
    }

    private func apply(_ changes: [NativeIdentityChange]) {
        for change in changes {
            switch change {
            case .register(let logicalNodeID, let sourceID, let nativeIdentifier):
                nativeIdentityRepository.register(NativeIdentityMapping(
                    logicalNodeID: logicalNodeID,
                    sourceID: sourceID,
                    nativeIdentifier: nativeIdentifier
                ))
            case .remove(let logicalNodeID, let sourceID):
                nativeIdentityRepository.remove(
                    logicalNodeID: logicalNodeID,
                    sourceID: sourceID
                )
            }
        }
    }

    private func result(
        for operation: SynchronizationOperation,
        status: WriteOperationStatus
    ) -> WriteOperationResult {
        WriteOperationResult(
            adapterIdentifier: identifier,
            sourceID: sourceID,
            logicalNodeID: operation.logicalNodeID,
            status: status
        )
    }
}
