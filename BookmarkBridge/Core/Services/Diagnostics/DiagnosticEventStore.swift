//
//  DiagnosticEventStore.swift
//  BookmarkBridge
//

import Foundation

/// Records allow-listed diagnostic events. Persistence failures are explicit so
/// callers can keep diagnostics strictly observational.
nonisolated protocol DiagnosticEventRecording: Sendable {
    func record(_ event: DiagnosticEvent, now: Date) async throws
}

/// Reads recent events in recording order, oldest first.
nonisolated protocol DiagnosticEventReading: Sendable {
    func recentEvents(limit: Int, now: Date) async throws -> [DiagnosticEvent]
}

nonisolated enum DiagnosticEventStoreError: Error, Equatable, Sendable {
    case corruptedData
    case unsupportedVersion(Int)
    case persistenceFailed
}

/// Private, bounded diagnostic journal stored under Application Support.
///
/// Events are already privacy-safe domain values. The store adds an independent
/// seven-day retention window, a 200-event capacity, atomic writes, and private
/// POSIX permissions. Its directory is injectable so tests never touch user data.
actor FileDiagnosticEventStore: DiagnosticEventRecording, DiagnosticEventReading {
    static let formatVersion = 1
    static let defaultCapacity = 200
    static let defaultRetention: TimeInterval = 7 * 24 * 60 * 60

    private struct Envelope: Codable {
        let version: Int
        let events: [DiagnosticEvent]
    }

    private let directory: URL
    private let fileURL: URL
    private let capacity: Int
    private let retention: TimeInterval
    private let fileManager: FileManager

    init(
        directory: URL,
        capacity: Int = FileDiagnosticEventStore.defaultCapacity,
        retention: TimeInterval = FileDiagnosticEventStore.defaultRetention,
        fileManager: FileManager = .default
    ) {
        self.directory = directory
        self.fileURL = directory.appending(
            path: "DiagnosticEvents.json",
            directoryHint: .notDirectory
        )
        self.capacity = max(1, capacity)
        self.retention = max(0, retention)
        self.fileManager = fileManager
    }

    static func inApplicationSupport() -> FileDiagnosticEventStore {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first
            ?? FileManager.default.temporaryDirectory
        return FileDiagnosticEventStore(
            directory: base.appending(
                path: "BookmarkBridge",
                directoryHint: .isDirectory
            )
        )
    }

    func record(_ event: DiagnosticEvent, now: Date) throws {
        let loaded = try loadEvents()
        var retained = retainedEvents(from: loaded, now: now)
        if isRetained(event, now: now) {
            retained.append(event)
        }
        if retained.count > capacity {
            retained.removeFirst(retained.count - capacity)
        }
        try persist(retained)
    }

    func recentEvents(limit: Int, now: Date) throws -> [DiagnosticEvent] {
        let loaded = try loadEvents()
        let retained = retainedEvents(from: loaded, now: now)
        if retained.count != loaded.count {
            try persist(retained)
        }
        let boundedLimit = min(max(0, limit), capacity)
        return Array(retained.suffix(boundedLimit))
    }

    private func retainedEvents(
        from events: [DiagnosticEvent],
        now: Date
    ) -> [DiagnosticEvent] {
        events.filter { isRetained($0, now: now) }
    }

    private func isRetained(_ event: DiagnosticEvent, now: Date) -> Bool {
        event.timestamp >= now.addingTimeInterval(-retention)
            && event.timestamp <= now
    }

    private func loadEvents() throws -> [DiagnosticEvent] {
        guard fileManager.fileExists(atPath: fileURL.path(percentEncoded: false)) else {
            return []
        }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw DiagnosticEventStoreError.persistenceFailed
        }

        let envelope: Envelope
        do {
            envelope = try JSONDecoder().decode(Envelope.self, from: data)
        } catch {
            throw DiagnosticEventStoreError.corruptedData
        }
        guard envelope.version == Self.formatVersion else {
            throw DiagnosticEventStoreError.unsupportedVersion(envelope.version)
        }
        return envelope.events
    }

    private func persist(_ events: [DiagnosticEvent]) throws {
        do {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try fileManager.setAttributes(
                [.posixPermissions: 0o700],
                ofItemAtPath: directory.path(percentEncoded: false)
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(
                Envelope(version: Self.formatVersion, events: events)
            )
            try data.write(to: fileURL, options: .atomic)
            try fileManager.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: fileURL.path(percentEncoded: false)
            )
        } catch let error as DiagnosticEventStoreError {
            throw error
        } catch {
            throw DiagnosticEventStoreError.persistenceFailed
        }
    }
}
