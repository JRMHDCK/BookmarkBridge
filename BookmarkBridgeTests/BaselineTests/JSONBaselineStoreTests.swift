//
//  JSONBaselineStoreTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("BSE JSON Baseline Store")
struct JSONBaselineStoreTests {
    @Test("Missing JSON file loads nil")
    func missingFile() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = JSONBaselineStore(fileURL: directory.appending(path: "baseline.json"))

        #expect(try await store.load() == nil)
    }

    @Test("JSON store round-trips the complete baseline")
    func roundTrip() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appending(path: "baseline.json")
        let store = JSONBaselineStore(fileURL: fileURL)
        let baseline = try BaselineTestSupport.baselineWithIdentity()

        try await store.save(baseline, expectedRevision: nil)

        #expect(try await store.load() == baseline)
        #expect(FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)))
    }

    @Test("JSON output is deterministic for the same baseline")
    func deterministicSerialization() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let firstURL = directory.appending(path: "first.json")
        let secondURL = directory.appending(path: "second.json")
        let baseline = try BaselineTestSupport.baselineWithIdentity()
        let firstStore = JSONBaselineStore(fileURL: firstURL)
        let secondStore = JSONBaselineStore(fileURL: secondURL)

        try await firstStore.save(baseline, expectedRevision: nil)
        try await secondStore.save(baseline, expectedRevision: nil)

        #expect(try Data(contentsOf: firstURL) == Data(contentsOf: secondURL))
    }

    @Test("JSON store enforces revision compare-and-save")
    func revisionConflict() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = JSONBaselineStore(fileURL: directory.appending(path: "baseline.json"))
        let original = try BaselineTestSupport.emptyBaseline()
        let updated = try BaselineEngine().apply(
            commands: [.createIdentity(CreateIdentityCommand(
                logicalNodeID: BaselineTestSupport.logicalID(1),
                observations: []
            ))],
            to: original
        ).baseline
        try await store.save(updated, expectedRevision: nil)

        await #expect(throws: BaselineError.revisionConflict(
            expected: .zero,
            actual: updated.revision
        )) {
            try await store.save(updated, expectedRevision: .zero)
        }
        #expect(try await store.load() == updated)
    }

    @Test("Corrupted JSON fails explicitly")
    func corruptedData() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appending(path: "baseline.json")
        try Data("not-json".utf8).write(to: fileURL)
        let store = JSONBaselineStore(fileURL: fileURL)

        await #expect(throws: BaselineError.corruptedData) {
            _ = try await store.load()
        }
    }

    @Test("Persisted baseline contains no browser content model")
    func browserIndependentPayload() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appending(path: "baseline.json")
        let store = JSONBaselineStore(fileURL: fileURL)
        try await store.save(
            BaselineTestSupport.baselineWithIdentity(),
            expectedRevision: nil
        )

        let json = String(decoding: try Data(contentsOf: fileURL), as: UTF8.self)

        #expect(!json.localizedCaseInsensitiveContains("safari"))
        #expect(!json.localizedCaseInsensitiveContains("chrome"))
        #expect(!json.contains("\"url\""))
        #expect(!json.contains("\"title\""))
        #expect(!json.contains("\"snapshot\""))
    }

    @Test("Failed initial save does not create a persistent file")
    func failedSaveIsNonDestructive() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let missingDirectory = directory.appending(path: "missing")
        let fileURL = missingDirectory.appending(path: "baseline.json")
        let store = JSONBaselineStore(fileURL: fileURL)

        await #expect(throws: BaselineError.storeFailure) {
            try await store.save(
                BaselineTestSupport.emptyBaseline(),
                expectedRevision: nil
            )
        }
        #expect(!FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)))
    }

    @Test("Transaction restoration reinstates the previous JSON Baseline")
    func transactionRestoration() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appending(path: "baseline.json")
        let store = JSONBaselineStore(fileURL: fileURL)
        let repository = BaselineRepository(store: store)
        let original = try BaselineTestSupport.emptyBaseline()
        try await store.save(original, expectedRevision: nil)
        let snapshot = try await repository.transactionSnapshot()
        let updated = try BaselineEngine().apply(
            commands: [.createIdentity(CreateIdentityCommand(
                logicalNodeID: BaselineTestSupport.logicalID(1),
                observations: []
            ))],
            to: original
        ).baseline

        try await store.save(updated, expectedRevision: original.revision)
        try await repository.restoreTransactionSnapshot(snapshot)

        #expect(try await store.load() == original)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "BookmarkBridge-BaselineTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
        return url
    }
}
