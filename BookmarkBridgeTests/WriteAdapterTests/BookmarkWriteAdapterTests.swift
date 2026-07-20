//
//  BookmarkWriteAdapterTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("BSE Write Adapter Contract")
struct BookmarkWriteAdapterTests {
    @Test("Adapter identifier is explicit and opaque")
    func identifier() {
        let uuid = WriteAdapterTestSupport.uuid(1)
        let identifier = WriteAdapterIdentifier(uuid)

        #expect(identifier.rawValue == uuid)
        #expect(identifier.description == uuid.uuidString)
    }

    @Test("Capabilities are typed and immutable")
    func capabilities() {
        let capabilities = WriteAdapterTestSupport.capabilities

        #expect(capabilities.supports(.create))
        #expect(capabilities.supports(.delete))
        #expect(capabilities.supports(.rename))
        #expect(capabilities.supports(.updateURL))
        #expect(capabilities.supports(.move))
        #expect(capabilities.supports(.reorder))
        #expect(!capabilities.supports(.archive))
        #expect(capabilities.supports(.dryRun))
    }

    @Test("Every synchronization operation maps to one typed capability")
    func operationCapabilities() {
        let operations = WriteAdapterTestSupport.operations
        let expected: [WriteAdapterCapability] = [
            .create, .delete, .rename, .updateURL, .move, .reorder, .archive,
        ]

        #expect(operations.map(\.requiredWriteCapability) == expected)
        #expect(operations.map(\.writeOperationKind) == [
            .create, .delete, .rename, .updateURL, .move, .reorder, .archive,
        ])
    }

    @Test("Execution context distinguishes dry-run from application")
    func executionContext() {
        let sourceID = WriteAdapterTestSupport.sourceID(1)
        let dryRun = WriteExecutionContext(sourceID: sourceID, mode: .dryRun)
        let apply = WriteExecutionContext(sourceID: sourceID, mode: .apply)

        #expect(dryRun.sourceID == apply.sourceID)
        #expect(dryRun.mode == .dryRun)
        #expect(apply.mode == .apply)
        #expect(dryRun != apply)
    }

    @Test(
        "Operation statuses remain distinct",
        arguments: [
            WriteOperationStatus.applied,
            .alreadySatisfied,
            .simulated,
        ]
    )
    func statuses(status: WriteOperationStatus) {
        #expect(WriteOperationStatus(rawValue: status.rawValue) == status)
    }

    @Test("Result retains adapter, source, node, and status")
    func result() {
        let result = WriteAdapterTestSupport.result(status: .applied)

        #expect(result.adapterIdentifier == WriteAdapterTestSupport.adapterID)
        #expect(result.sourceID == WriteAdapterTestSupport.sourceID(1))
        #expect(result.logicalNodeID == WriteAdapterTestSupport.logicalID(1))
        #expect(result.status == .applied)
    }

    @Test("A stateless adapter receives exactly one operation and context")
    func execute() async throws {
        let operation = WriteAdapterTestSupport.operations[0]
        let context = WriteExecutionContext(
            sourceID: WriteAdapterTestSupport.sourceID(1),
            mode: .apply
        )
        let expected = WriteAdapterTestSupport.result(status: .applied)
        let adapter = ControlledWriteAdapter(
            identifier: WriteAdapterTestSupport.adapterID,
            capabilities: WriteAdapterTestSupport.capabilities,
            expectedOperation: operation,
            expectedContext: context,
            outcome: .success(expected)
        )

        let actual = try await execute(
            using: adapter,
            operation: operation,
            context: context
        )

        #expect(actual == expected)
    }

    @Test("Typed adapter errors propagate without reinterpretation")
    func errorPropagation() async {
        let operation = WriteAdapterTestSupport.operations[1]
        let context = WriteExecutionContext(
            sourceID: WriteAdapterTestSupport.sourceID(1),
            mode: .apply
        )
        let expectedError = WriteAdapterError.executionFailed(.delete)
        let adapter = ControlledWriteAdapter(
            identifier: WriteAdapterTestSupport.adapterID,
            capabilities: WriteAdapterTestSupport.capabilities,
            expectedOperation: operation,
            expectedContext: context,
            outcome: .failure(expectedError)
        )

        await #expect(throws: expectedError) {
            _ = try await adapter.execute(operation: operation, context: context)
        }
    }

    @Test("Serializable contract values round-trip")
    func codableRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let identifier = WriteAdapterTestSupport.adapterID
        let capabilities = WriteAdapterTestSupport.capabilities
        let context = WriteExecutionContext(
            sourceID: WriteAdapterTestSupport.sourceID(1),
            mode: .dryRun
        )
        let result = WriteAdapterTestSupport.result(status: .simulated)
        let error = WriteAdapterError.unsupportedCapability(.archive)

        #expect(try decoder.decode(
            WriteAdapterIdentifier.self,
            from: encoder.encode(identifier)
        ) == identifier)
        #expect(try decoder.decode(
            WriteAdapterCapabilities.self,
            from: encoder.encode(capabilities)
        ) == capabilities)
        #expect(try decoder.decode(
            WriteExecutionContext.self,
            from: encoder.encode(context)
        ) == context)
        #expect(try decoder.decode(
            WriteOperationResult.self,
            from: encoder.encode(result)
        ) == result)
        #expect(try decoder.decode(
            WriteAdapterError.self,
            from: encoder.encode(error)
        ) == error)
    }

    @Test("Protocol and values satisfy Swift Concurrency boundaries")
    func strictConcurrency() {
        let context = WriteExecutionContext(
            sourceID: WriteAdapterTestSupport.sourceID(1),
            mode: .dryRun
        )
        let adapter = ControlledWriteAdapter(
            identifier: WriteAdapterTestSupport.adapterID,
            capabilities: WriteAdapterTestSupport.capabilities,
            expectedOperation: WriteAdapterTestSupport.operations[0],
            expectedContext: context,
            outcome: .success(WriteAdapterTestSupport.result(status: .simulated))
        )

        requireSendable(adapter)
        requireSendable(adapter as any BookmarkWriteAdapter)
        requireSendable(context)
        requireSendable(WriteAdapterTestSupport.result(status: .simulated))
        requireSendable(WriteAdapterError.sourceUnavailable(
            sourceID: WriteAdapterTestSupport.sourceID(1)
        ))
    }

    private func execute(
        using adapter: any BookmarkWriteAdapter,
        operation: SynchronizationOperation,
        context: WriteExecutionContext
    ) async throws -> WriteOperationResult {
        try await adapter.execute(operation: operation, context: context)
    }

    private func requireSendable<T: Sendable>(_ value: T) { _ = value }
}

private nonisolated struct ControlledWriteAdapter: BookmarkWriteAdapter {
    let identifier: WriteAdapterIdentifier
    let capabilities: WriteAdapterCapabilities
    let expectedOperation: SynchronizationOperation
    let expectedContext: WriteExecutionContext
    let outcome: Result<WriteOperationResult, WriteAdapterError>

    func execute(
        operation: SynchronizationOperation,
        context: WriteExecutionContext
    ) async throws -> WriteOperationResult {
        guard operation == expectedOperation,
              context == expectedContext else {
            throw WriteAdapterError.invalidOperation(operation.writeOperationKind)
        }
        return try outcome.get()
    }
}

private enum WriteAdapterTestSupport {
    static let adapterID = WriteAdapterIdentifier(uuid(900))

    static let capabilities = WriteAdapterCapabilities(
        canCreate: true,
        canDelete: true,
        canRename: true,
        canUpdateURL: true,
        canMove: true,
        canReorder: true,
        canArchive: false,
        canDryRun: true
    )

    static let operations: [SynchronizationOperation] = [
        .create(CreateNodeOperation(
            logicalNodeID: logicalID(1),
            kind: .folder,
            title: "Folder",
            url: nil,
            parentID: nil,
            position: 0
        )),
        .delete(DeleteNodeOperation(logicalNodeID: logicalID(1))),
        .rename(RenameNodeOperation(logicalNodeID: logicalID(1), title: "Renamed")),
        .updateURL(UpdateURLOperation(
            logicalNodeID: logicalID(1),
            url: URL(string: "https://example.test")!
        )),
        .move(MoveNodeOperation(
            logicalNodeID: logicalID(1),
            parentID: logicalID(2),
            position: 0
        )),
        .reorder(ReorderNodeOperation(logicalNodeID: logicalID(1), position: 2)),
        .archive(ArchiveNodeOperation(
            logicalNodeID: logicalID(1),
            state: .archived
        )),
    ]

    static func result(status: WriteOperationStatus) -> WriteOperationResult {
        WriteOperationResult(
            adapterIdentifier: adapterID,
            sourceID: sourceID(1),
            logicalNodeID: logicalID(1),
            status: status
        )
    }

    static func sourceID(_ value: Int) -> BSESourceID {
        BSESourceID(uuid(value))
    }

    static func logicalID(_ value: Int) -> LogicalNodeID {
        LogicalNodeID(uuid(value))
    }

    static func uuid(_ value: Int) -> UUID {
        UUID(uuidString: String(
            format: "00000000-0000-0000-0000-%012d",
            value
        ))!
    }
}
