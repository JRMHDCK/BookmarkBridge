//
//  ChromeBookmarkWriteAdapterTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Synchronization
import Testing
@testable import BookmarkBridge

@Suite("BSE Chrome bookmark write adapter")
struct ChromeBookmarkWriteAdapterTests {
    @Test("Apply executes load, mutate, save, then register in exact order")
    func registerOrder() async throws {
        let setup = try ChromeWriteAdapterTestSupport.setup(changes: [
            .register(
                logicalNodeID: ChromeWriteAdapterTestSupport.nodeID,
                sourceID: ChromeWriteAdapterTestSupport.sourceID,
                nativeIdentifier: ChromeWriteAdapterTestSupport.nativeID
            ),
        ])

        let result = try await setup.adapter.execute(
            operation: ChromeWriteAdapterTestSupport.operation,
            context: ChromeWriteAdapterTestSupport.applyContext
        )

        #expect(result == ChromeWriteAdapterTestSupport.expectedResult(status: .applied))
        #expect(setup.recorder.events == [
            .load,
            .mutate(ChromeWriteAdapterTestSupport.operation),
            .save,
            .register(
                ChromeWriteAdapterTestSupport.nodeID,
                ChromeWriteAdapterTestSupport.sourceID,
                ChromeWriteAdapterTestSupport.nativeID
            ),
        ])
    }

    @Test("Apply executes load, mutate, save, then remove in exact order")
    func removeOrder() async throws {
        let setup = try ChromeWriteAdapterTestSupport.setup(
            changes: [
                .remove(
                    logicalNodeID: ChromeWriteAdapterTestSupport.nodeID,
                    sourceID: ChromeWriteAdapterTestSupport.sourceID
                ),
            ],
            mappings: [ChromeWriteAdapterTestSupport.mapping]
        )

        _ = try await setup.adapter.execute(
            operation: ChromeWriteAdapterTestSupport.operation,
            context: ChromeWriteAdapterTestSupport.applyContext
        )

        #expect(setup.recorder.events == [
            .load,
            .mutate(ChromeWriteAdapterTestSupport.operation),
            .save,
            .remove(
                ChromeWriteAdapterTestSupport.nodeID,
                ChromeWriteAdapterTestSupport.sourceID
            ),
        ])
        #expect(setup.repository.nativeIdentifier(
            for: ChromeWriteAdapterTestSupport.nodeID,
            sourceID: ChromeWriteAdapterTestSupport.sourceID
        ) == nil)
    }

    @Test("Dry-run loads and mutates only in memory")
    func dryRun() async throws {
        let setup = try ChromeWriteAdapterTestSupport.setup(changes: [
            .register(
                logicalNodeID: ChromeWriteAdapterTestSupport.nodeID,
                sourceID: ChromeWriteAdapterTestSupport.sourceID,
                nativeIdentifier: ChromeWriteAdapterTestSupport.nativeID
            ),
        ])

        let result = try await setup.adapter.execute(
            operation: ChromeWriteAdapterTestSupport.operation,
            context: WriteExecutionContext(
                sourceID: ChromeWriteAdapterTestSupport.sourceID,
                mode: .dryRun
            )
        )

        #expect(result == ChromeWriteAdapterTestSupport.expectedResult(status: .simulated))
        #expect(setup.recorder.events == [
            .load,
            .mutate(ChromeWriteAdapterTestSupport.operation),
        ])
        #expect(setup.repository.changeCount == 0)
    }

    @Test("A mutation without identity changes stops after save")
    func noIdentityChanges() async throws {
        let setup = try ChromeWriteAdapterTestSupport.setup()

        _ = try await setup.adapter.execute(
            operation: ChromeWriteAdapterTestSupport.operation,
            context: ChromeWriteAdapterTestSupport.applyContext
        )

        #expect(setup.recorder.events == [
            .load,
            .mutate(ChromeWriteAdapterTestSupport.operation),
            .save,
        ])
        #expect(setup.repository.changeCount == 0)
    }

    @Test("Load failure stops before mutation, save, and repository changes")
    func loadFailure() async throws {
        let setup = try ChromeWriteAdapterTestSupport.setup(loadFailure: .load)

        await #expect(throws: ChromeWriteAdapterTestFailure.load) {
            _ = try await setup.adapter.execute(
                operation: ChromeWriteAdapterTestSupport.operation,
                context: ChromeWriteAdapterTestSupport.applyContext
            )
        }

        #expect(setup.recorder.events == [.load])
        #expect(setup.repository.changeCount == 0)
    }

    @Test("Mutation failure stops before save and repository changes")
    func mutationFailure() async throws {
        let setup = try ChromeWriteAdapterTestSupport.setup(mutationFailure: .mutation)

        await #expect(throws: ChromeWriteAdapterTestFailure.mutation) {
            _ = try await setup.adapter.execute(
                operation: ChromeWriteAdapterTestSupport.operation,
                context: ChromeWriteAdapterTestSupport.applyContext
            )
        }

        #expect(setup.recorder.events == [
            .load,
            .mutate(ChromeWriteAdapterTestSupport.operation),
        ])
        #expect(setup.repository.changeCount == 0)
    }

    @Test("Save failure leaves the repository unchanged")
    func saveFailure() async throws {
        let setup = try ChromeWriteAdapterTestSupport.setup(
            changes: [
                .register(
                    logicalNodeID: ChromeWriteAdapterTestSupport.nodeID,
                    sourceID: ChromeWriteAdapterTestSupport.sourceID,
                    nativeIdentifier: ChromeWriteAdapterTestSupport.nativeID
                ),
            ],
            saveFailure: .save
        )

        await #expect(throws: ChromeWriteAdapterTestFailure.save) {
            _ = try await setup.adapter.execute(
                operation: ChromeWriteAdapterTestSupport.operation,
                context: ChromeWriteAdapterTestSupport.applyContext
            )
        }

        #expect(setup.recorder.events == [
            .load,
            .mutate(ChromeWriteAdapterTestSupport.operation),
            .save,
        ])
        #expect(setup.repository.changeCount == 0)
        #expect(setup.repository.nativeIdentifier(
            for: ChromeWriteAdapterTestSupport.nodeID,
            sourceID: ChromeWriteAdapterTestSupport.sourceID
        ) == nil)
    }

    @Test("Several identity changes retain their order and payload after save")
    func multipleIdentityChanges() async throws {
        let removedID = ChromeWriteAdapterTestSupport.logicalID(2)
        let changeSourceID = ChromeWriteAdapterTestSupport.sourceIDValue(2)
        let removedMapping = NativeIdentityMapping(
            logicalNodeID: removedID,
            sourceID: changeSourceID,
            nativeIdentifier: NativeNodeIdentifier("removed-native")
        )
        let setup = try ChromeWriteAdapterTestSupport.setup(
            changes: [
                .register(
                    logicalNodeID: ChromeWriteAdapterTestSupport.nodeID,
                    sourceID: changeSourceID,
                    nativeIdentifier: ChromeWriteAdapterTestSupport.nativeID
                ),
                .remove(logicalNodeID: removedID, sourceID: changeSourceID),
            ],
            mappings: [removedMapping]
        )

        _ = try await setup.adapter.execute(
            operation: ChromeWriteAdapterTestSupport.operation,
            context: ChromeWriteAdapterTestSupport.applyContext
        )

        #expect(setup.recorder.events == [
            .load,
            .mutate(ChromeWriteAdapterTestSupport.operation),
            .save,
            .register(
                ChromeWriteAdapterTestSupport.nodeID,
                changeSourceID,
                ChromeWriteAdapterTestSupport.nativeID
            ),
            .remove(removedID, changeSourceID),
        ])
        #expect(setup.repository.nativeIdentifier(
            for: ChromeWriteAdapterTestSupport.nodeID,
            sourceID: changeSourceID
        ) == ChromeWriteAdapterTestSupport.nativeID)
    }

    @Test("Archive is rejected before touching Chrome persistence")
    func archiveUnsupported() async throws {
        let setup = try ChromeWriteAdapterTestSupport.setup()
        let archive = SynchronizationOperation.archive(ArchiveNodeOperation(
            logicalNodeID: ChromeWriteAdapterTestSupport.nodeID,
            state: .archived
        ))

        await #expect(throws: WriteAdapterError.unsupportedCapability(.archive)) {
            _ = try await setup.adapter.execute(
                operation: archive,
                context: ChromeWriteAdapterTestSupport.applyContext
            )
        }

        #expect(setup.recorder.events.isEmpty)
        #expect(setup.repository.changeCount == 0)
    }

    @Test("A mismatched source is rejected before load")
    func sourceMismatch() async throws {
        let setup = try ChromeWriteAdapterTestSupport.setup()
        let otherSourceID = ChromeWriteAdapterTestSupport.sourceIDValue(3)

        await #expect(throws: WriteAdapterError.sourceMismatch(
            expected: ChromeWriteAdapterTestSupport.sourceID,
            actual: otherSourceID
        )) {
            _ = try await setup.adapter.execute(
                operation: ChromeWriteAdapterTestSupport.operation,
                context: WriteExecutionContext(sourceID: otherSourceID, mode: .apply)
            )
        }

        #expect(setup.recorder.events.isEmpty)
    }

    @Test("Capabilities match the Chrome mutator contract")
    func capabilities() throws {
        let capabilities = try ChromeWriteAdapterTestSupport.setup().adapter.capabilities

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
        let first = try ChromeWriteAdapterTestSupport.setup()
        let second = try ChromeWriteAdapterTestSupport.setup()

        let firstResult = try await first.adapter.execute(
            operation: ChromeWriteAdapterTestSupport.operation,
            context: ChromeWriteAdapterTestSupport.applyContext
        )
        let secondResult = try await second.adapter.execute(
            operation: ChromeWriteAdapterTestSupport.operation,
            context: ChromeWriteAdapterTestSupport.applyContext
        )

        #expect(firstResult == secondResult)
        #expect(first.recorder.events == second.recorder.events)
    }

    @Test("Adapter and test seams satisfy Sendable boundaries")
    func strictConcurrency() throws {
        let setup = try ChromeWriteAdapterTestSupport.setup()

        requireSendable(setup.adapter)
        requireSendable(setup.adapter as any BookmarkWriteAdapter)
        requireSendable(setup.store as any ChromeBookmarkStoring)
        requireSendable(setup.mutator as any ChromeBookmarkMutating)
    }

    private func requireSendable<T: Sendable>(_ value: T) { _ = value }
}

private nonisolated enum ChromeWriteAdapterTestFailure: Error, Hashable, Sendable {
    case load
    case mutation
    case save
}

private nonisolated enum ChromeWriteAdapterTestEvent: Hashable, Sendable {
    case load
    case mutate(SynchronizationOperation)
    case save
    case register(LogicalNodeID, BSESourceID, NativeNodeIdentifier)
    case remove(LogicalNodeID, BSESourceID)
}

private nonisolated final class ChromeWriteAdapterCallRecorder: Sendable {
    private let storage = Mutex<[ChromeWriteAdapterTestEvent]>([])

    var events: [ChromeWriteAdapterTestEvent] { storage.withLock { $0 } }

    func append(_ event: ChromeWriteAdapterTestEvent) {
        storage.withLock { $0.append(event) }
    }
}

private nonisolated struct ControlledChromeBookmarkStore: ChromeBookmarkStoring {
    let recorder: ChromeWriteAdapterCallRecorder
    let document: ChromeBookmarkDocument
    let loadFailure: ChromeWriteAdapterTestFailure?
    let saveFailure: ChromeWriteAdapterTestFailure?

    func load() throws -> ChromeBookmarkDocument {
        recorder.append(.load)
        if let loadFailure { throw loadFailure }
        return document
    }

    func save(_ document: ChromeBookmarkDocument) throws -> URL {
        recorder.append(.save)
        if let saveFailure { throw saveFailure }
        return URL(filePath: "/test-only/Bookmarks.backup")
    }
}

private nonisolated struct ControlledChromeBookmarkMutator: ChromeBookmarkMutating {
    let recorder: ChromeWriteAdapterCallRecorder
    let result: ChromeBookmarkMutationResult
    let failure: ChromeWriteAdapterTestFailure?

    func apply(
        _ operation: SynchronizationOperation,
        to document: ChromeBookmarkDocument
    ) throws -> ChromeBookmarkMutationResult {
        recorder.append(.mutate(operation))
        if let failure { throw failure }
        return result
    }
}

private nonisolated final class ControlledChromeNativeIdentityRepository: NativeIdentityRepository {
    private struct State: Sendable {
        var mappings: [MappingKey: NativeNodeIdentifier]
        var changeCount = 0
    }

    private struct MappingKey: Hashable, Sendable {
        let logicalNodeID: LogicalNodeID
        let sourceID: BSESourceID
    }

    private let recorder: ChromeWriteAdapterCallRecorder
    private let state: Mutex<State>

    init(
        recorder: ChromeWriteAdapterCallRecorder,
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

    func logicalNodeID(
        for nativeIdentifier: NativeNodeIdentifier,
        sourceID: BSESourceID
    ) -> LogicalNodeID? {
        state.withLock { state in
            state.mappings.first { key, value in
                key.sourceID == sourceID && value == nativeIdentifier
            }?.key.logicalNodeID
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

private nonisolated enum ChromeWriteAdapterTestSupport {
    struct Setup {
        let adapter: ChromeBookmarkWriteAdapter
        let store: ControlledChromeBookmarkStore
        let mutator: ControlledChromeBookmarkMutator
        let repository: ControlledChromeNativeIdentityRepository
        let recorder: ChromeWriteAdapterCallRecorder
    }

    static let adapterID = WriteAdapterIdentifier(UUID(900))
    static let sourceID = sourceIDValue(1)
    static let nodeID = logicalID(1)
    static let nativeID = NativeNodeIdentifier("chrome-native-node-1")
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
        loadFailure: ChromeWriteAdapterTestFailure? = nil,
        mutationFailure: ChromeWriteAdapterTestFailure? = nil,
        saveFailure: ChromeWriteAdapterTestFailure? = nil
    ) throws -> Setup {
        let recorder = ChromeWriteAdapterCallRecorder()
        let originalDocument = try document(marker: "before")
        let mutatedDocument = try document(marker: "after")
        let store = ControlledChromeBookmarkStore(
            recorder: recorder,
            document: originalDocument,
            loadFailure: loadFailure,
            saveFailure: saveFailure
        )
        let mutator = ControlledChromeBookmarkMutator(
            recorder: recorder,
            result: ChromeBookmarkMutationResult(
                document: mutatedDocument,
                nativeIdentityChanges: changes
            ),
            failure: mutationFailure
        )
        let repository = ControlledChromeNativeIdentityRepository(
            recorder: recorder,
            mappings: mappings
        )
        return Setup(
            adapter: ChromeBookmarkWriteAdapter(
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

    static func document(marker: String) throws -> ChromeBookmarkDocument {
        let object: [String: Any] = [
            "version": 1,
            "roots": [:],
            "test_marker": marker,
        ]
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return try ChromeBookmarkDocument(
            data: data,
            sourceFingerprint: ChromeDocumentFingerprint(
                contentDigest: ChromeDocumentFingerprint.digest(of: data),
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
