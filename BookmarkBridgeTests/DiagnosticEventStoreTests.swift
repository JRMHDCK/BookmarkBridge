//
//  DiagnosticEventStoreTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("Diagnostic event store")
struct DiagnosticEventStoreTests {
    @Test("Keeps only the configured event capacity")
    func capacityIsBounded() async throws {
        let fixture = try Fixture(capacity: 3)
        defer { fixture.remove() }

        for index in 0..<5 {
            try await fixture.store.record(
                event(at: fixture.now.addingTimeInterval(TimeInterval(index))),
                now: fixture.now.addingTimeInterval(10)
            )
        }

        let events = try await fixture.store.recentEvents(
            limit: 20,
            now: fixture.now.addingTimeInterval(10)
        )
        #expect(events.count == 3)
        #expect(events.map(\.timestamp) == [
            fixture.now.addingTimeInterval(2),
            fixture.now.addingTimeInterval(3),
            fixture.now.addingTimeInterval(4),
        ])
    }

    @Test("Purges events older than the retention window")
    func retentionIsBounded() async throws {
        let fixture = try Fixture(retention: 60)
        defer { fixture.remove() }
        let old = event(at: fixture.now.addingTimeInterval(-61))
        let boundary = event(at: fixture.now.addingTimeInterval(-60))
        let recent = event(at: fixture.now.addingTimeInterval(-1))

        try await fixture.store.record(old, now: old.timestamp)
        try await fixture.store.record(boundary, now: boundary.timestamp)
        try await fixture.store.record(recent, now: recent.timestamp)

        let events = try await fixture.store.recentEvents(
            limit: 50,
            now: fixture.now
        )
        #expect(events.map(\.timestamp) == [boundary.timestamp, recent.timestamp])
    }

    @Test("Returns the latest requested events in recording order")
    func recentLimitPreservesOrder() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }

        for index in 0..<4 {
            try await fixture.store.record(
                event(at: fixture.now.addingTimeInterval(TimeInterval(index))),
                now: fixture.now.addingTimeInterval(100)
            )
        }

        let events = try await fixture.store.recentEvents(
            limit: 2,
            now: fixture.now.addingTimeInterval(100)
        )
        #expect(events.map(\.timestamp) == [
            fixture.now.addingTimeInterval(2),
            fixture.now.addingTimeInterval(3),
        ])
    }

    @Test("Persists events for a new store instance")
    func persistenceSurvivesReopening() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let expected = event(at: fixture.now)
        try await fixture.store.record(expected, now: fixture.now)

        let reopened = FileDiagnosticEventStore(directory: fixture.directory)
        let events = try await reopened.recentEvents(limit: 50, now: fixture.now)

        #expect(events == [expected])
    }

    @Test("Uses private directory and file permissions")
    func privatePermissions() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try await fixture.store.record(event(at: fixture.now), now: fixture.now)

        let directoryAttributes = try FileManager.default.attributesOfItem(
            atPath: fixture.directory.path(percentEncoded: false)
        )
        let fileAttributes = try FileManager.default.attributesOfItem(
            atPath: fixture.fileURL.path(percentEncoded: false)
        )
        #expect(directoryAttributes[.posixPermissions] as? Int == 0o700)
        #expect(fileAttributes[.posixPermissions] as? Int == 0o600)
    }

    @Test("Rejects a corrupted journal without exposing its path")
    func corruptedDataIsRejected() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try Data("private-user-content".utf8).write(to: fixture.fileURL)

        await #expect(throws: DiagnosticEventStoreError.corruptedData) {
            try await fixture.store.recentEvents(limit: 50, now: fixture.now)
        }
    }

    @Test("Does not retain events dated in the future")
    func futureEventsAreRejected() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }

        try await fixture.store.record(
            event(at: fixture.now.addingTimeInterval(1)),
            now: fixture.now
        )

        let events = try await fixture.store.recentEvents(
            limit: 50,
            now: fixture.now
        )
        #expect(events.isEmpty)
    }

    @Test("Rejects unsupported journal versions")
    func unsupportedVersionIsRejected() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let data = try JSONSerialization.data(withJSONObject: [
            "version": 99,
            "events": [],
        ])
        try data.write(to: fixture.fileURL)

        await #expect(throws: DiagnosticEventStoreError.unsupportedVersion(99)) {
            try await fixture.store.recentEvents(limit: 50, now: fixture.now)
        }
    }

    @Test("Serializes concurrent recording through the actor")
    func concurrentRecordingIsSafe() async throws {
        let fixture = try Fixture(capacity: 200)
        defer { fixture.remove() }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<100 {
                group.addTask {
                    try await fixture.store.record(
                        event(
                            at: fixture.now.addingTimeInterval(
                                TimeInterval(index)
                            )
                        ),
                        now: fixture.now.addingTimeInterval(100)
                    )
                }
            }
            try await group.waitForAll()
        }

        let events = try await fixture.store.recentEvents(
            limit: 200,
            now: fixture.now.addingTimeInterval(100)
        )
        #expect(events.count == 100)
    }

    private func event(at timestamp: Date) -> DiagnosticEvent {
        DiagnosticEvent(
            timestamp: timestamp,
            level: .information,
            component: .synchronization,
            stage: .preview,
            outcome: .succeeded,
            source: .chromeLocal,
            durationMilliseconds: 12,
            counts: DiagnosticCounts(bookmarks: 4, folders: 2)
        )
    }
}

private struct Fixture: Sendable {
    let directory: URL
    let fileURL: URL
    let store: FileDiagnosticEventStore
    let now = Date(timeIntervalSince1970: 1_786_464_000)

    init(
        capacity: Int = FileDiagnosticEventStore.defaultCapacity,
        retention: TimeInterval = FileDiagnosticEventStore.defaultRetention
    ) throws {
        directory = FileManager.default.temporaryDirectory.appending(
            path: "bb-diagnostic-store-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        fileURL = directory.appending(
            path: "DiagnosticEvents.json",
            directoryHint: .notDirectory
        )
        store = FileDiagnosticEventStore(
            directory: directory,
            capacity: capacity,
            retention: retention
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }
}
