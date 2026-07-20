//
//  SafariBookmarkWriteAdapterTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Synchronization
import Testing
@testable import BookmarkBridge

@Suite("BSE Safari bookmark write adapter")
struct SafariBookmarkWriteAdapterTests {
    @Test("Apply executes load, mutate, save, then register in exact order")
    func registerOrder() async throws {
        let setup = try AdapterTestSupport.setup(changes: [
            .register(
                logicalNodeID: AdapterTestSupport.nodeID,
                sourceID: AdapterTestSupport.sourceID,
                nativeIdentifier: AdapterTestSupport.nativeID
            ),
        ])

        let result = try await setup.adapter.execute(
            operation: AdapterTestSupport.operation,
            context: AdapterTestSupport.applyContext
        )

        #expect(result == AdapterTestSupport.expectedResult(status: .applied))
        #expect(setup.recorder.events == [
            .load,
            .mutate(AdapterTestSupport.operation),
            .save,
            .register(
                AdapterTestSupport.nodeID,
                AdapterTestSupport.sourceID,
                AdapterTestSupport.nativeID
            ),
        ])
        #expect(setup.repository.nativeIdentifier(
            for: AdapterTestSupport.nodeID,
            sourceID: AdapterTestSupport.sourceID
        ) == AdapterTestSupport.nativeID)
    }

    @Test("Apply executes load, mutate, save, then remove in exact order")
    func removeOrder() async throws {
        let setup = try AdapterTestSupport.setup(
            changes: [
                .remove(
                    logicalNodeID: AdapterTestSupport.nodeID,
                    sourceID: AdapterTestSupport.sourceID
                ),
            ],
            mappings: [AdapterTestSupport.mapping]
        )

        _ = try await setup.adapter.execute(
            operation: AdapterTestSupport.operation,
            context: AdapterTestSupport.applyContext
        )

        #expect(setup.recorder.events == [
            .load,
            .mutate(AdapterTestSupport.operation),
            .save,
            .remove(AdapterTestSupport.nodeID, AdapterTestSupport.sourceID),
        ])
        #expect(setup.repository.nativeIdentifier(
            for: AdapterTestSupport.nodeID,
            sourceID: AdapterTestSupport.sourceID
        ) == nil)
    }

    @Test("A mutation without identity changes stops after save")
    func noIdentityChanges() async throws {
        let setup = try AdapterTestSupport.setup()

        _ = try await setup.adapter.execute(
            operation: AdapterTestSupport.operation,
            context: AdapterTestSupport.applyContext
        )

        #expect(setup.recorder.events == [
            .load,
            .mutate(AdapterTestSupport.operation),
            .save,
        ])
        #expect(setup.repository.changeCount == 0)
    }

    @Test("Load failure stops before mutation and persistence")
    func loadFailure() async throws {
        let setup = try AdapterTestSupport.setup(loadFailure: .load)

        await #expect(throws: AdapterTestFailure.load) {
            _ = try await setup.adapter.execute(
                operation: AdapterTestSupport.operation,
                context: AdapterTestSupport.applyContext
            )
        }

        #expect(setup.recorder.events == [.load])
        #expect(setup.repository.changeCount == 0)
    }

    @Test("Mutation failure stops before save")
    func mutationFailure() async throws {
        let setup = try AdapterTestSupport.setup(mutationFailure: .mutation)

        await #expect(throws: AdapterTestFailure.mutation) {
            _ = try await setup.adapter.execute(
                operation: AdapterTestSupport.operation,
                context: AdapterTestSupport.applyContext
            )
        }

        #expect(setup.recorder.events == [
            .load,
            .mutate(AdapterTestSupport.operation),
        ])
        #expect(setup.repository.changeCount == 0)
    }

    @Test("Save failure never applies deferred identity changes")
    func saveFailure() async throws {
        let setup = try AdapterTestSupport.setup(
            changes: [
                .register(
                    logicalNodeID: AdapterTestSupport.nodeID,
                    sourceID: AdapterTestSupport.sourceID,
                    nativeIdentifier: AdapterTestSupport.nativeID
                ),
            ],
            saveFailure: .save
        )

        await #expect(throws: AdapterTestFailure.save) {
            _ = try await setup.adapter.execute(
                operation: AdapterTestSupport.operation,
                context: AdapterTestSupport.applyContext
            )
        }

        #expect(setup.recorder.events == [
            .load,
            .mutate(AdapterTestSupport.operation),
            .save,
        ])
        #expect(setup.repository.nativeIdentifier(
            for: AdapterTestSupport.nodeID,
            sourceID: AdapterTestSupport.sourceID
        ) == nil)
        #expect(setup.repository.changeCount == 0)
    }

    @Test("Several identity changes are applied sequentially after save")
    func multipleIdentityChanges() async throws {
        let removedID = AdapterTestSupport.logicalID(2)
        let changes: [NativeIdentityChange] = [
            .register(
                logicalNodeID: AdapterTestSupport.nodeID,
                sourceID: AdapterTestSupport.sourceID,
                nativeIdentifier: AdapterTestSupport.nativeID
            ),
            .remove(
                logicalNodeID: removedID,
                sourceID: AdapterTestSupport.sourceID
            ),
        ]
        let setup = try AdapterTestSupport.setup(
            changes: changes,
            mappings: [NativeIdentityMapping(
                logicalNodeID: removedID,
                sourceID: AdapterTestSupport.sourceID,
                nativeIdentifier: NativeNodeIdentifier("removed-native-id")
            )]
        )

        _ = try await setup.adapter.execute(
            operation: AdapterTestSupport.operation,
            context: AdapterTestSupport.applyContext
        )

        #expect(setup.recorder.events == [
            .load,
            .mutate(AdapterTestSupport.operation),
            .save,
            .register(
                AdapterTestSupport.nodeID,
                AdapterTestSupport.sourceID,
                AdapterTestSupport.nativeID
            ),
            .remove(removedID, AdapterTestSupport.sourceID),
        ])
    }

    @Test("Deferred changes retain their source and native identifier verbatim")
    func identityPayload() async throws {
        let changeSourceID = AdapterTestSupport.sourceIDValue(2)
        let nativeID = NativeNodeIdentifier("opaque-native-value")
        let setup = try AdapterTestSupport.setup(changes: [
            .register(
                logicalNodeID: AdapterTestSupport.nodeID,
                sourceID: changeSourceID,
                nativeIdentifier: nativeID
            ),
        ])

        _ = try await setup.adapter.execute(
            operation: AdapterTestSupport.operation,
            context: AdapterTestSupport.applyContext
        )

        #expect(setup.repository.nativeIdentifier(
            for: AdapterTestSupport.nodeID,
            sourceID: changeSourceID
        ) == nativeID)
        #expect(setup.repository.nativeIdentifier(
            for: AdapterTestSupport.nodeID,
            sourceID: AdapterTestSupport.sourceID
        ) == nil)
    }

    @Test("Archive is rejected before touching persistence")
    func archiveUnsupported() async throws {
        let setup = try AdapterTestSupport.setup()
        let archive = SynchronizationOperation.archive(ArchiveNodeOperation(
            logicalNodeID: AdapterTestSupport.nodeID,
            state: .archived
        ))

        await #expect(throws: WriteAdapterError.unsupportedCapability(.archive)) {
            _ = try await setup.adapter.execute(
                operation: archive,
                context: AdapterTestSupport.applyContext
            )
        }

        #expect(setup.recorder.events.isEmpty)
        #expect(setup.repository.changeCount == 0)
    }

    @Test("A mismatched source is rejected before load")
    func sourceMismatch() async throws {
        let setup = try AdapterTestSupport.setup()
        let otherSourceID = AdapterTestSupport.sourceIDValue(3)

        await #expect(throws: WriteAdapterError.sourceMismatch(
            expected: AdapterTestSupport.sourceID,
            actual: otherSourceID
        )) {
            _ = try await setup.adapter.execute(
                operation: AdapterTestSupport.operation,
                context: WriteExecutionContext(sourceID: otherSourceID, mode: .apply)
            )
        }

        #expect(setup.recorder.events.isEmpty)
    }

    @Test("Dry-run mutates only in memory and never saves or updates identities")
    func dryRun() async throws {
        let setup = try AdapterTestSupport.setup(changes: [
            .register(
                logicalNodeID: AdapterTestSupport.nodeID,
                sourceID: AdapterTestSupport.sourceID,
                nativeIdentifier: AdapterTestSupport.nativeID
            ),
        ])

        let result = try await setup.adapter.execute(
            operation: AdapterTestSupport.operation,
            context: WriteExecutionContext(
                sourceID: AdapterTestSupport.sourceID,
                mode: .dryRun
            )
        )

        #expect(result.status == .simulated)
        #expect(setup.recorder.events == [
            .load,
            .mutate(AdapterTestSupport.operation),
        ])
        #expect(setup.repository.changeCount == 0)
    }

    @Test("Capabilities expose every supported Safari mutation")
    func capabilities() throws {
        let setup = try AdapterTestSupport.setup()
        let capabilities = setup.adapter.capabilities

        #expect(capabilities.canCreate)
        #expect(capabilities.canDelete)
        #expect(capabilities.canRename)
        #expect(capabilities.canUpdateURL)
        #expect(capabilities.canMove)
        #expect(capabilities.canReorder)
        #expect(!capabilities.canArchive)
        #expect(capabilities.canDryRun)
    }

    @Test("Same inputs produce the same result and orchestration trace")
    func deterministic() async throws {
        let first = try AdapterTestSupport.setup()
        let second = try AdapterTestSupport.setup()

        let firstResult = try await first.adapter.execute(
            operation: AdapterTestSupport.operation,
            context: AdapterTestSupport.applyContext
        )
        let secondResult = try await second.adapter.execute(
            operation: AdapterTestSupport.operation,
            context: AdapterTestSupport.applyContext
        )

        #expect(firstResult == secondResult)
        #expect(first.recorder.events == second.recorder.events)
    }

    @Test("Adapter and test seams satisfy Sendable boundaries")
    func strictConcurrency() throws {
        let setup = try AdapterTestSupport.setup()

        requireSendable(setup.adapter)
        requireSendable(setup.adapter as any BookmarkWriteAdapter)
        requireSendable(setup.store as any SafariBookmarkStoring)
        requireSendable(setup.mutator as any SafariBookmarkMutating)
    }

    private func requireSendable<T: Sendable>(_ value: T) { _ = value }
}

private nonisolated enum AdapterTestFailure: Error, Hashable, Sendable {
    case load
    case mutation
    case save
}

private nonisolated enum AdapterTestEvent: Hashable, Sendable {
    case load
    case mutate(SynchronizationOperation)
    case save
    case register(LogicalNodeID, BSESourceID, NativeNodeIdentifier)
    case remove(LogicalNodeID, BSESourceID)
}

private nonisolated final class AdapterCallRecorder: Sendable {
    private let storage = Mutex<[AdapterTestEvent]>([])

    var events: [AdapterTestEvent] { storage.withLock { $0 } }

    func append(_ event: AdapterTestEvent) {
        storage.withLock { $0.append(event) }
    }
}

private nonisolated struct ControlledSafariBookmarkStore: SafariBookmarkStoring {
    let recorder: AdapterCallRecorder
    let document: SafariBookmarkDocument
    let loadFailure: AdapterTestFailure?
    let saveFailure: AdapterTestFailure?

    func load() throws -> SafariBookmarkDocument {
        recorder.append(.load)
        if let loadFailure { throw loadFailure }
        return document
    }

    func save(_ document: SafariBookmarkDocument) throws -> URL {
        recorder.append(.save)
        if let saveFailure { throw saveFailure }
        return URL(filePath: "/test-only/backup.plist")
    }
}

private nonisolated struct ControlledSafariBookmarkMutator: SafariBookmarkMutating {
    let recorder: AdapterCallRecorder
    let result: SafariBookmarkMutationResult
    let failure: AdapterTestFailure?

    func apply(
        _ operation: SynchronizationOperation,
        to document: SafariBookmarkDocument
    ) throws -> SafariBookmarkMutationResult {
        recorder.append(.mutate(operation))
        if let failure { throw failure }
        return result
    }
}

private nonisolated final class ControlledNativeIdentityRepository: NativeIdentityRepository {
    private struct State: Sendable {
        var mappings: [MappingKey: NativeNodeIdentifier]
        var changeCount = 0
    }

    private struct MappingKey: Hashable, Sendable {
        let logicalNodeID: LogicalNodeID
        let sourceID: BSESourceID
    }

    private let recorder: AdapterCallRecorder
    private let state: Mutex<State>

    init(
        recorder: AdapterCallRecorder,
        mappings: [NativeIdentityMapping]
    ) {
        self.recorder = recorder
        state = Mutex(State(mappings: Dictionary(
            uniqueKeysWithValues: mappings.map {
                (MappingKey(
                    logicalNodeID: $0.logicalNodeID,
                    sourceID: $0.sourceID
                ), $0.nativeIdentifier)
            }
        )))
    }

    var changeCount: Int { state.withLock { $0.changeCount } }

    func nativeIdentifier(
        for logicalNodeID: LogicalNodeID,
        sourceID: BSESourceID
    ) -> NativeNodeIdentifier? {
        state.withLock {
            $0.mappings[MappingKey(logicalNodeID: logicalNodeID, sourceID: sourceID)]
        }
    }

    func register(_ mapping: NativeIdentityMapping) {
        recorder.append(.register(
            mapping.logicalNodeID,
            mapping.sourceID,
            mapping.nativeIdentifier
        ))
        state.withLock {
            $0.mappings[MappingKey(
                logicalNodeID: mapping.logicalNodeID,
                sourceID: mapping.sourceID
            )] = mapping.nativeIdentifier
            $0.changeCount += 1
        }
    }

    func remove(logicalNodeID: LogicalNodeID, sourceID: BSESourceID) {
        recorder.append(.remove(logicalNodeID, sourceID))
        state.withLock {
            $0.mappings.removeValue(forKey: MappingKey(
                logicalNodeID: logicalNodeID,
                sourceID: sourceID
            ))
            $0.changeCount += 1
        }
    }
}

private nonisolated enum AdapterTestSupport {
    struct Setup {
        let adapter: SafariBookmarkWriteAdapter
        let store: ControlledSafariBookmarkStore
        let mutator: ControlledSafariBookmarkMutator
        let repository: ControlledNativeIdentityRepository
        let recorder: AdapterCallRecorder
    }

    static let adapterID = WriteAdapterIdentifier(UUID(900))
    static let sourceID = sourceIDValue(1)
    static let nodeID = logicalID(1)
    static let nativeID = NativeNodeIdentifier("native-node-1")
    static let operation = SynchronizationOperation.rename(RenameNodeOperation(
        logicalNodeID: nodeID,
        title: "Renamed"
    ))
    static let applyContext = WriteExecutionContext(sourceID: sourceID, mode: .apply)
    static let mapping = NativeIdentityMapping(
        logicalNodeID: nodeID,
        sourceID: sourceID,
        nativeIdentifier: nativeID
    )

    static func setup(
        changes: [NativeIdentityChange] = [],
        mappings: [NativeIdentityMapping] = [],
        loadFailure: AdapterTestFailure? = nil,
        mutationFailure: AdapterTestFailure? = nil,
        saveFailure: AdapterTestFailure? = nil
    ) throws -> Setup {
        let recorder = AdapterCallRecorder()
        let originalDocument = try document(marker: "before")
        let mutatedDocument = try document(marker: "after")
        let store = ControlledSafariBookmarkStore(
            recorder: recorder,
            document: originalDocument,
            loadFailure: loadFailure,
            saveFailure: saveFailure
        )
        let mutator = ControlledSafariBookmarkMutator(
            recorder: recorder,
            result: SafariBookmarkMutationResult(
                document: mutatedDocument,
                nativeIdentityChanges: changes
            ),
            failure: mutationFailure
        )
        let repository = ControlledNativeIdentityRepository(
            recorder: recorder,
            mappings: mappings
        )
        return Setup(
            adapter: SafariBookmarkWriteAdapter(
                identifier: adapterID,
                sourceID: sourceID,
                store: store,
                mutator: mutator,
                nativeIdentityRepository: repository
            ),
            store: store,
            mutator: mutator,
            repository: repository,
            recorder: recorder
        )
    }

    static func expectedResult(status: WriteOperationStatus) -> WriteOperationResult {
        WriteOperationResult(
            adapterIdentifier: adapterID,
            sourceID: sourceID,
            logicalNodeID: nodeID,
            status: status
        )
    }

    static func document(marker: String) throws -> SafariBookmarkDocument {
        let propertyList: [String: Any] = [
            "WebBookmarkType": "WebBookmarkTypeList",
            "WebBookmarkUUID": "root",
            "Title": marker,
            "Children": [],
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: propertyList,
            format: .binary,
            options: 0
        )
        return try SafariBookmarkDocument(
            data: data,
            sourceFingerprint: SafariDocumentFingerprint(
                contentDigest: SafariDocumentFingerprint.digest(of: data),
                fileSize: UInt64(data.count),
                modificationDate: Date(timeIntervalSinceReferenceDate: 0),
                fileSystemNumber: 1,
                fileNumber: 1
            )
        )
    }

    static func sourceIDValue(_ value: Int) -> BSESourceID {
        BSESourceID(UUID(value))
    }

    static func logicalID(_ value: Int) -> LogicalNodeID {
        LogicalNodeID(UUID(value))
    }

    static func UUID(_ value: Int) -> Foundation.UUID {
        Foundation.UUID(uuidString: String(
            format: "00000000-0000-0000-0000-%012d",
            value
        ))!
    }
}
