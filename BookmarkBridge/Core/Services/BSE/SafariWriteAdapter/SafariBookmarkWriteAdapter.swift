//
//  SafariBookmarkWriteAdapter.swift
//  BookmarkBridge
//

import Foundation

/// Persistence seam used only to keep adapter orchestration independently testable.
nonisolated protocol SafariBookmarkStoring: Sendable {
    func load() throws -> SafariBookmarkDocument

    @discardableResult
    func save(_ document: SafariBookmarkDocument) throws -> URL
}

/// Mutation seam used only to verify orchestration without duplicating mutation logic.
nonisolated protocol SafariBookmarkMutating: Sendable {
    func apply(
        _ operation: SynchronizationOperation,
        to document: SafariBookmarkDocument
    ) throws -> SafariBookmarkMutationResult
}

extension SafariBookmarkStore: SafariBookmarkStoring {}
extension SafariBookmarkMutator: SafariBookmarkMutating {}

/// Executes exactly one Safari write by composing persistence and in-memory
/// mutation. It applies deferred native-identity changes only after persistence.
nonisolated struct SafariBookmarkWriteAdapter: BookmarkWriteAdapter {
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
    private let store: any SafariBookmarkStoring
    private let mutator: any SafariBookmarkMutating
    private let nativeIdentityRepository: any NativeIdentityRepository

    init(
        identifier: WriteAdapterIdentifier,
        sourceID: BSESourceID,
        store: SafariBookmarkStore,
        mutator: SafariBookmarkMutator,
        nativeIdentityRepository: any NativeIdentityRepository
    ) {
        self.init(
            identifier: identifier,
            sourceID: sourceID,
            store: store as any SafariBookmarkStoring,
            mutator: mutator as any SafariBookmarkMutating,
            nativeIdentityRepository: nativeIdentityRepository
        )
    }

    init(
        identifier: WriteAdapterIdentifier,
        sourceID: BSESourceID,
        store: any SafariBookmarkStoring,
        mutator: any SafariBookmarkMutating,
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

        // The backup URL is intentionally retained by the persistence layer.
        // BookmarkWriteAdapter has no field through which to expose it.
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
