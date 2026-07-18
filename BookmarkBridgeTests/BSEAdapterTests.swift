//
//  BSEAdapterTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("BSE Adapter")
struct BSEAdapterTests {
    private func logicalID(_ value: Int) throws -> LogicalNodeID {
        let string = String(format: "80000000-0000-0000-0000-%012d", value)
        return LogicalNodeID(try #require(UUID(uuidString: string)))
    }

    private func sourceID(_ value: Int) throws -> BSESourceID {
        let string = String(format: "81000000-0000-0000-0000-%012d", value)
        return BSESourceID(try #require(UUID(uuidString: string)))
    }

    private func restorePointID(_ value: Int) throws -> BSEAdapterRestorePointID {
        let string = String(format: "82000000-0000-0000-0000-%012d", value)
        return BSEAdapterRestorePointID(try #require(UUID(uuidString: string)))
    }

    private func capabilities(
        _ supported: Set<BSEAdapterCapability> = Set([
            .read,
            .write,
            .create,
            .delete,
            .move,
            .rename,
            .verify,
            .createRestorePoint,
            .restore,
        ])
    ) -> BSEAdapterCapabilities {
        BSEAdapterCapabilities(
            canRead: supported.contains(.read),
            canWrite: supported.contains(.write),
            canCreate: supported.contains(.create),
            canDelete: supported.contains(.delete),
            canMove: supported.contains(.move),
            canRename: supported.contains(.rename),
            canVerify: supported.contains(.verify),
            canCreateRestorePoint: supported.contains(.createRestorePoint),
            canRestore: supported.contains(.restore)
        )
    }

    private func snapshot(sourceID: BSESourceID) throws -> BSESnapshot {
        BSESnapshot(
            source: sourceID,
            capturedAt: Date(timeIntervalSince1970: 1_750_000_000),
            tree: try BSETree(nodes: [])
        )
    }

    private func folder(
        _ value: Int,
        title: String = "Folder",
        parent: Int? = nil,
        position: Int = 0
    ) throws -> BSENode {
        try BSENode(
            logicalID: logicalID(value),
            kind: .folder,
            title: title,
            parentID: try parent.map(logicalID),
            position: position
        )
    }

    private func step(_ kind: ExecutionStepKind) throws -> ExecutionStep {
        let logicalID = try logicalID(10)
        let before: BSENode?
        let after: BSENode?
        let eventKind: BSEEventKind
        let reason: DiffReason

        switch kind {
        case .create:
            before = nil
            after = try folder(10)
            eventKind = .createNode
            reason = .createdInAfterSnapshot
        case .delete:
            before = try folder(10)
            after = nil
            eventKind = .deleteNode
            reason = .missingFromAfterSnapshot
        case .move:
            before = try folder(10, parent: 1)
            after = try folder(10, parent: 2)
            eventKind = .moveNode
            reason = .parentChanged
        case .rename:
            before = try folder(10, title: "Before")
            after = try folder(10, title: "After")
            eventKind = .renameNode
            reason = .titleChanged
        }

        let entry = DiffEntry(
            event: try BSEEvent(
                kind: eventKind,
                logicalID: logicalID,
                before: before,
                after: after
            ),
            reason: reason
        )
        let resolution = ConflictResolution(
            logicalID: logicalID,
            kind: .applyLeft,
            reason: .changedOnlyInLeft,
            leftEntries: [entry],
            rightEntries: []
        )
        return ExecutionStep(
            kind: kind,
            logicalID: logicalID,
            entry: entry,
            resolution: resolution
        )
    }

    private func adapter(
        capabilities: BSEAdapterCapabilities? = nil,
        permissionStatus: BSEAdapterPermissionStatus = BSEAdapterPermissionStatus(state: .granted),
        compatibility: BSEAdapterCompatibility = BSEAdapterCompatibility(state: .supported),
        executionResult: BSEAdapterExecutionResult = .applied,
        verificationResult: BSEAdapterVerificationResult = .satisfied,
        executionError: BSEAdapterError? = nil
    ) throws -> TestBSEAdapter {
        let sourceID = try sourceID(1)
        return TestBSEAdapter(
            sourceID: sourceID,
            capabilities: capabilities ?? self.capabilities(),
            permissionStatus: permissionStatus,
            compatibility: compatibility,
            snapshot: try snapshot(sourceID: sourceID),
            executionResult: executionResult,
            verificationResult: verificationResult,
            restorePoint: BSEAdapterRestorePoint(
                restorePointID: try restorePointID(1),
                sourceID: sourceID
            ),
            executionError: executionError
        )
    }

    // MARK: - Reading and source observations

    @Test("Reading returns the adapter snapshot")
    func readingReturnsSnapshot() async throws {
        let adapter = try adapter()

        let result = try await adapter.readSnapshot()

        #expect(result == (try snapshot(sourceID: adapter.sourceID)))
    }

    @Test("Reading never mutates the source")
    func readingIsNonDestructive() async throws {
        let adapter = try adapter()

        _ = try await adapter.readSnapshot()

        #expect(await adapter.sourceMutationCount() == 0)
        #expect(await adapter.executedSteps() == [])
    }

    @Test(
        "Permission observations preserve every universal state",
        arguments: [
            BSEAdapterPermissionState.granted,
            .denied,
            .notDetermined,
            .unavailable,
        ]
    )
    func permissionStates(state: BSEAdapterPermissionState) async throws {
        let status = BSEAdapterPermissionStatus(
            state: state,
            detail: BSEAdapterPermissionDetail(
                code: permissionDetailCode(for: state),
                explanation: "Controlled test observation"
            )
        )
        let adapter = try adapter(permissionStatus: status)

        #expect(await adapter.checkPermissions() == status)
        #expect(await adapter.permissionRequestCount() == 0)
    }

    @Test(
        "Compatibility observations preserve every universal state",
        arguments: [
            BSEAdapterCompatibilityState.supported,
            .unsupported,
            .untested,
            .unavailable,
        ]
    )
    func compatibilityStates(state: BSEAdapterCompatibilityState) async throws {
        let compatibility = BSEAdapterCompatibility(
            state: state,
            detail: BSEAdapterCompatibilityDetail(
                code: compatibilityDetailCode(for: state),
                sourceVersion: BSEAdapterSourceVersion("1.2.3"),
                explanation: "Controlled test observation"
            )
        )
        let adapter = try adapter(compatibility: compatibility)

        #expect(await adapter.checkCompatibility() == compatibility)
    }

    @Test("Reading is refused before I/O when canRead is false")
    func readingCapabilityIsRequired() async throws {
        let adapter = try adapter(capabilities: capabilities([]))

        await #expect(throws: BSEAdapterError.unsupportedCapability(.read)) {
            _ = try await adapter.readSnapshot()
        }
        #expect(await adapter.readCount() == 0)
    }

    // MARK: - Atomic execution

    @Test("Writing is refused before I/O when canWrite is false")
    func writingCapabilityIsRequired() async throws {
        let adapter = try adapter(capabilities: capabilities([.create]))

        await #expect(throws: BSEAdapterError.unsupportedCapability(.write)) {
            _ = try await adapter.execute(step(.create))
        }
        #expect(await adapter.executionAttemptCount() == 0)
    }

    @Test(
        "Each supported operation executes without changing its intent",
        arguments: [
            ExecutionStepKind.create,
            .delete,
            .move,
            .rename,
        ]
    )
    func supportedOperationsRetainTheirKind(kind: ExecutionStepKind) async throws {
        let adapter = try adapter()
        let expectedStep = try step(kind)

        #expect(try await adapter.execute(expectedStep) == .applied)

        let executedStep = try #require(await adapter.executedSteps().first)
        #expect(executedStep == expectedStep)
        #expect(executedStep.kind == kind)
    }

    @Test("An unsupported operation is refused before any write")
    func unsupportedOperationIsRefusedBeforeWriting() async throws {
        let adapter = try adapter(capabilities: capabilities([.write, .create]))

        await #expect(throws: BSEAdapterError.unsupportedCapability(.rename)) {
            _ = try await adapter.execute(step(.rename))
        }
        #expect(await adapter.executionAttemptCount() == 0)
        #expect(await adapter.sourceMutationCount() == 0)
    }

    @Test("Applied reports a performed write")
    func appliedResult() async throws {
        let adapter = try adapter(executionResult: .applied)

        #expect(try await adapter.execute(step(.create)) == .applied)
        #expect(await adapter.sourceMutationCount() == 1)
    }

    @Test("Already-satisfied reports idempotence without writing")
    func alreadySatisfiedResult() async throws {
        let adapter = try adapter(executionResult: .alreadySatisfied)

        #expect(try await adapter.execute(step(.create)) == .alreadySatisfied)
        #expect(await adapter.sourceMutationCount() == 0)
    }

    @Test("An execution failure is explicit and does not continue automatically")
    func explicitExecutionFailureStopsImmediately() async throws {
        let adapter = try adapter(executionError: .executionFailed(.move))

        await #expect(throws: BSEAdapterError.executionFailed(.move)) {
            _ = try await adapter.execute(step(.move))
        }
        #expect(await adapter.executionAttemptCount() == 1)
        #expect(await adapter.executedSteps() == [])
        #expect(await adapter.sourceMutationCount() == 0)
        #expect(await adapter.restorationCount() == 0)
    }

    @Test("The same observed state and step produce the same result")
    func executionIsDeterministic() async throws {
        let first = try adapter(executionResult: .alreadySatisfied)
        let second = try adapter(executionResult: .alreadySatisfied)
        let step = try step(.delete)

        let firstResult = try await first.execute(step)
        let secondResult = try await second.execute(step)
        let firstSteps = await first.executedSteps()
        let secondSteps = await second.executedSteps()

        #expect(firstResult == secondResult)
        #expect(firstSteps == secondSteps)
    }

    // MARK: - Verification

    @Test(
        "Verification returns supported observations",
        arguments: [
            BSEAdapterVerificationResult.satisfied,
            .notSatisfied,
        ]
    )
    func supportedVerification(result: BSEAdapterVerificationResult) async throws {
        let adapter = try adapter(verificationResult: result)

        #expect(try await adapter.verify(step(.rename)) == result)
        #expect(await adapter.verificationCount() == 1)
        #expect(await adapter.sourceMutationCount() == 0)
    }

    @Test("Verification returns unsupported without observing the source")
    func unsupportedVerification() async throws {
        let adapter = try adapter(capabilities: capabilities([.read]))

        #expect(try await adapter.verify(step(.rename)) == .unsupported)
        #expect(await adapter.verificationCount() == 0)
    }

    // MARK: - Restore points

    @Test("Creating a restore point returns universal opaque metadata")
    func createsRestorePoint() async throws {
        let adapter = try adapter()

        let restorePoint = try await adapter.createRestorePoint()

        #expect(restorePoint.sourceID == adapter.sourceID)
        #expect(restorePoint.restorePointID == (try restorePointID(1)))
        #expect(await adapter.restorePointCreationCount() == 1)
    }

    @Test("Restore reuses a matching source restore point")
    func restoresMatchingPoint() async throws {
        let adapter = try adapter()
        let restorePoint = try await adapter.createRestorePoint()

        try await adapter.restore(from: restorePoint)

        #expect(await adapter.restoredPoints() == [restorePoint])
        #expect(await adapter.restorationCount() == 1)
    }

    @Test("Restore-point creation reports an unsupported capability")
    func unsupportedRestorePointCreation() async throws {
        let adapter = try adapter(capabilities: capabilities([.read]))

        await #expect(throws: BSEAdapterError.unsupportedCapability(.createRestorePoint)) {
            _ = try await adapter.createRestorePoint()
        }
        #expect(await adapter.restorePointCreationCount() == 0)
    }

    @Test("Restoration reports an unsupported capability")
    func unsupportedRestoration() async throws {
        let adapter = try adapter(capabilities: capabilities([.createRestorePoint]))
        let restorePoint = BSEAdapterRestorePoint(
            restorePointID: try restorePointID(1),
            sourceID: adapter.sourceID
        )

        await #expect(throws: BSEAdapterError.unsupportedCapability(.restore)) {
            try await adapter.restore(from: restorePoint)
        }
        #expect(await adapter.restorationCount() == 0)
    }

    @Test("A restore point from another source is rejected")
    func restorePointSourceMustMatch() async throws {
        let adapter = try adapter()
        let otherSource = try sourceID(2)
        let restorePoint = BSEAdapterRestorePoint(
            restorePointID: try restorePointID(2),
            sourceID: otherSource
        )

        await #expect(throws: BSEAdapterError.sourceMismatch(
            expected: adapter.sourceID,
            actual: otherSource
        )) {
            try await adapter.restore(from: restorePoint)
        }
        #expect(await adapter.restorationCount() == 0)
    }

    // MARK: - Value semantics and serialization

    @Test("Adapter models are immutable hashable values")
    func modelsHaveValueSemantics() throws {
        let originalCapabilities = capabilities()
        let copiedCapabilities = originalCapabilities
        let status = BSEAdapterPermissionStatus(state: .granted)
        let compatibility = BSEAdapterCompatibility(state: .supported)
        let restorePoint = BSEAdapterRestorePoint(
            restorePointID: try restorePointID(1),
            sourceID: try sourceID(1)
        )

        #expect(copiedCapabilities == originalCapabilities)
        #expect(Set([originalCapabilities, copiedCapabilities]).count == 1)
        #expect(Set([status]).contains(status))
        #expect(Set([compatibility]).contains(compatibility))
        #expect(Set([restorePoint]).contains(restorePoint))
    }

    @Test("Adapter models preserve values through Codable round trips")
    func codableRoundTrips() throws {
        let permission = BSEAdapterPermissionStatus(
            state: .denied,
            detail: BSEAdapterPermissionDetail(code: .accessDenied, explanation: "Denied")
        )
        let compatibility = BSEAdapterCompatibility(
            state: .untested,
            detail: BSEAdapterCompatibilityDetail(
                code: .versionNotValidated,
                sourceVersion: BSEAdapterSourceVersion("9.9")
            )
        )
        let restorePoint = BSEAdapterRestorePoint(
            restorePointID: try restorePointID(1),
            sourceID: try sourceID(1)
        )

        #expect(try roundTrip(capabilities()) == capabilities())
        #expect(try roundTrip(permission) == permission)
        #expect(try roundTrip(compatibility) == compatibility)
        #expect(try roundTrip(BSEAdapterExecutionResult.applied) == .applied)
        #expect(try roundTrip(BSEAdapterVerificationResult.unsupported) == .unsupported)
        #expect(try roundTrip(restorePoint) == restorePoint)
        #expect(try roundTrip(BSEAdapterError.sourceMismatch(
            expected: sourceID(1),
            actual: sourceID(2)
        )) == .sourceMismatch(expected: sourceID(1), actual: sourceID(2)))
    }

    @Test("Production adapter abstractions contain no concrete browser reference")
    func productionAbstractionsAreBrowserAgnostic() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let adapterDirectory = repositoryRoot
            .appendingPathComponent("BookmarkBridge/Core/Services/BSE/Adapters")
        let sourceFiles = try FileManager.default.contentsOfDirectory(
            at: adapterDirectory,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "swift" }

        #expect(!sourceFiles.isEmpty)
        for sourceFile in sourceFiles {
            let source = try String(contentsOf: sourceFile, encoding: .utf8).lowercased()
            #expect(!source.contains("safari"))
            #expect(!source.contains("chrome"))
        }
    }

    private func permissionDetailCode(
        for state: BSEAdapterPermissionState
    ) -> BSEAdapterPermissionDetailCode {
        switch state {
        case .granted: .authorized
        case .denied: .accessDenied
        case .notDetermined: .authorizationRequired
        case .unavailable: .sourceUnavailable
        }
    }

    private func compatibilityDetailCode(
        for state: BSEAdapterCompatibilityState
    ) -> BSEAdapterCompatibilityDetailCode {
        switch state {
        case .supported: .versionInSupportedRange
        case .unsupported: .versionOutsideSupportedRange
        case .untested: .versionNotValidated
        case .unavailable: .sourceUnavailable
        }
    }

    private func roundTrip<Value>(_ value: Value) throws -> Value
    where Value: Codable & Equatable {
        let encoded = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(Value.self, from: encoded)
    }
}

private actor TestBSEAdapter: BSEAdapter {
    nonisolated let sourceID: BSESourceID
    nonisolated let capabilities: BSEAdapterCapabilities

    private let permissionStatus: BSEAdapterPermissionStatus
    private let compatibility: BSEAdapterCompatibility
    private let snapshot: BSESnapshot
    private let executionResult: BSEAdapterExecutionResult
    private let verificationResult: BSEAdapterVerificationResult
    private let restorePoint: BSEAdapterRestorePoint
    private let executionError: BSEAdapterError?
    private let validator = BSEAdapterCapabilityValidator()

    private var storedReadCount = 0
    private var storedPermissionRequestCount = 0
    private var storedExecutionAttemptCount = 0
    private var storedVerificationCount = 0
    private var storedRestorePointCreationCount = 0
    private var storedSourceMutationCount = 0
    private var storedExecutedSteps: [ExecutionStep] = []
    private var storedRestoredPoints: [BSEAdapterRestorePoint] = []

    init(
        sourceID: BSESourceID,
        capabilities: BSEAdapterCapabilities,
        permissionStatus: BSEAdapterPermissionStatus,
        compatibility: BSEAdapterCompatibility,
        snapshot: BSESnapshot,
        executionResult: BSEAdapterExecutionResult,
        verificationResult: BSEAdapterVerificationResult,
        restorePoint: BSEAdapterRestorePoint,
        executionError: BSEAdapterError?
    ) {
        self.sourceID = sourceID
        self.capabilities = capabilities
        self.permissionStatus = permissionStatus
        self.compatibility = compatibility
        self.snapshot = snapshot
        self.executionResult = executionResult
        self.verificationResult = verificationResult
        self.restorePoint = restorePoint
        self.executionError = executionError
    }

    func checkPermissions() async -> BSEAdapterPermissionStatus {
        permissionStatus
    }

    func checkCompatibility() async -> BSEAdapterCompatibility {
        compatibility
    }

    func readSnapshot() async throws -> BSESnapshot {
        try validator.validateReading(capabilities: capabilities)
        storedReadCount += 1
        return snapshot
    }

    func execute(_ step: ExecutionStep) async throws -> BSEAdapterExecutionResult {
        try validator.validateExecution(step, capabilities: capabilities)
        storedExecutionAttemptCount += 1
        if let executionError { throw executionError }

        storedExecutedSteps.append(step)
        if executionResult == .applied {
            storedSourceMutationCount += 1
        }
        return executionResult
    }

    func verify(_ step: ExecutionStep) async throws -> BSEAdapterVerificationResult {
        if let unsupported = validator.unsupportedVerificationResult(capabilities: capabilities) {
            return unsupported
        }
        storedVerificationCount += 1
        return verificationResult
    }

    func createRestorePoint() async throws -> BSEAdapterRestorePoint {
        try validator.validateRestorePointCreation(capabilities: capabilities)
        storedRestorePointCreationCount += 1
        return restorePoint
    }

    func restore(from restorePoint: BSEAdapterRestorePoint) async throws {
        try validator.validateRestoration(
            from: restorePoint,
            sourceID: sourceID,
            capabilities: capabilities
        )
        storedRestoredPoints.append(restorePoint)
    }

    func readCount() -> Int { storedReadCount }
    func permissionRequestCount() -> Int { storedPermissionRequestCount }
    func executionAttemptCount() -> Int { storedExecutionAttemptCount }
    func verificationCount() -> Int { storedVerificationCount }
    func restorePointCreationCount() -> Int { storedRestorePointCreationCount }
    func sourceMutationCount() -> Int { storedSourceMutationCount }
    func restorationCount() -> Int { storedRestoredPoints.count }
    func executedSteps() -> [ExecutionStep] { storedExecutedSteps }
    func restoredPoints() -> [BSEAdapterRestorePoint] { storedRestoredPoints }
}
