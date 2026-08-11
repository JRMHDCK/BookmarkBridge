//
//  DiagnosticReportGenerationTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("Diagnostic report generation")
struct DiagnosticReportGenerationTests {
    @Test("Builds a private report with the latest fifty events")
    func buildsCompleteReport() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let events = (0..<60).map { index in
            diagnosticEvent(
                at: fixture.now.addingTimeInterval(TimeInterval(index - 60))
            )
        }
        let reader = StubDiagnosticEventReader(events: events)
        let builder = makeBuilder(fixture: fixture, reader: reader)

        let artifact = try await builder.build(
            origin: .contextualError,
            context: diagnosticContext,
            now: fixture.now
        )

        #expect(artifact.report.id.rawValue == "BB-A73F29")
        #expect(artifact.report.events.count == 50)
        #expect(artifact.report.events.first == events[10])
        #expect(artifact.report.journalStatus == .available)
        #expect(await reader.requestedLimit == 50)
        #expect(artifact.fileURL.lastPathComponent == "BookmarkBridge-BB-A73F29.txt")
        #expect(try String(contentsOf: artifact.fileURL, encoding: .utf8) == artifact.text)

        let attributes = try FileManager.default.attributesOfItem(
            atPath: artifact.fileURL.path(percentEncoded: false)
        )
        #expect(attributes[.posixPermissions] as? Int == 0o600)
    }

    @Test("Renders every required allow-listed field deterministically")
    func textIsDeterministic() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let reader = StubDiagnosticEventReader(events: [
            diagnosticEvent(at: fixture.now.addingTimeInterval(-1)),
        ])
        let builder = makeBuilder(fixture: fixture, reader: reader)

        let first = try await builder.build(
            origin: .contextualError,
            context: diagnosticContext,
            now: fixture.now
        )
        let second = try await builder.build(
            origin: .contextualError,
            context: diagnosticContext,
            now: fixture.now
        )

        #expect(first.text == second.text)
        for expected in [
            "report_id=BB-A73F29",
            "app_version=0.9.2",
            "app_build=1",
            "macos_version=26.5.1",
            "architecture=arm64",
            "direction=chromeToSafari",
            "stage=sourceRead",
            "error_type=authorization",
            "error_code=accessDenied",
            "duration_ms=184",
            "bookmarks=120",
            "folders=18",
            "matches=95",
            "changes=7",
            "safari_authorization=granted",
            "chrome_authorization=denied",
            "journal_status=available",
            "events_count=1",
        ] {
            #expect(first.text.contains(expected))
        }
    }

    @Test("Never includes personal bookmark or filesystem data")
    func generatedTextContainsNoPersonalData() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let builder = makeBuilder(
            fixture: fixture,
            reader: StubDiagnosticEventReader(events: [
                diagnosticEvent(at: fixture.now),
            ])
        )
        let artifact = try await builder.build(
            origin: .helpCenter,
            context: diagnosticContext,
            now: fixture.now
        )

        for forbidden in [
            "https://private.example/favorite",
            "Titre favori privé",
            "Dossier personnel",
            "BRICKS PRO",
            "/Users/jerome",
            "security-scoped-bookmark-secret",
        ] {
            #expect(!artifact.text.localizedCaseInsensitiveContains(forbidden))
        }
    }

    @Test("Still creates a report when the journal is corrupted")
    func corruptedJournalDoesNotBlockReport() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let builder = makeBuilder(
            fixture: fixture,
            reader: StubDiagnosticEventReader(
                error: DiagnosticEventStoreError.corruptedData
            )
        )

        let artifact = try await builder.build(
            origin: .helpCenter,
            context: DiagnosticContext(),
            now: fixture.now
        )

        #expect(artifact.report.journalStatus == .corrupted)
        #expect(artifact.report.events.isEmpty)
        #expect(artifact.text.contains("journal_status=corrupted"))
    }

    @Test("Removes only expired BookmarkBridge report files")
    func expiresOldReportsSafely() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let store = FileDiagnosticReportStore(
            directory: fixture.directory,
            maximumAge: 60
        )
        let oldReport = fixture.directory.appending(
            path: "BookmarkBridge-BB-000001.txt"
        )
        let unrelated = fixture.directory.appending(path: "keep-me.txt")
        try Data("old".utf8).write(to: oldReport)
        try Data("private".utf8).write(to: unrelated)
        let oldDate = fixture.now.addingTimeInterval(-61)
        try FileManager.default.setAttributes(
            [.modificationDate: oldDate],
            ofItemAtPath: oldReport.path(percentEncoded: false)
        )
        try FileManager.default.setAttributes(
            [.modificationDate: oldDate],
            ofItemAtPath: unrelated.path(percentEncoded: false)
        )
        let identifier = try #require(DiagnosticReportID("BB-A73F29"))

        let currentReport = try await store.write(
            text: "safe",
            reportID: identifier,
            now: fixture.now
        )

        #expect(!FileManager.default.fileExists(atPath: oldReport.path()))
        #expect(FileManager.default.fileExists(atPath: unrelated.path()))
        try await store.removeReport(at: currentReport)
        #expect(!FileManager.default.fileExists(atPath: currentReport.path()))
    }

    @Test("Maps file failures without retaining a local path")
    func fileFailureIsTyped() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let blockingFile = fixture.directory.appending(path: "blocking")
        try Data("not-a-directory".utf8).write(to: blockingFile)
        let builder = DefaultDiagnosticReportBuilder(
            eventReader: StubDiagnosticEventReader(events: []),
            application: applicationInfo,
            system: systemInfo,
            identifierGenerator: FixedDiagnosticReportIDGenerator(),
            fileWriter: FileDiagnosticReportStore(directory: blockingFile)
        )

        await #expect(
            throws: DiagnosticReportGenerationError.fileCreationFailed
        ) {
            _ = try await builder.build(
                origin: .helpCenter,
                context: DiagnosticContext(),
                now: fixture.now
            )
        }
    }

    @Test("Current environment values respect the safe version contract")
    func currentEnvironmentIsSafe() {
        let application = DiagnosticEnvironment.applicationInfo()
        let system = DiagnosticEnvironment.systemInfo()

        #expect(!application.version.rawValue.isEmpty)
        #expect(!application.build.rawValue.isEmpty)
        #expect(!system.macOSVersion.rawValue.isEmpty)
        #expect([
            DiagnosticMachineArchitecture.arm64,
            .x86_64,
            .unknown,
        ].contains(system.architecture))
    }

    private var diagnosticContext: DiagnosticContext {
        DiagnosticContext(
            direction: .chromeToSafari,
            stage: .sourceRead,
            errorType: .authorization,
            errorCode: .accessDenied,
            durationMilliseconds: 184,
            counts: DiagnosticCounts(
                bookmarks: 120,
                folders: 18,
                matches: 95,
                changes: 7
            ),
            safariAuthorization: .granted,
            chromeAuthorization: .denied
        )
    }

    private var applicationInfo: DiagnosticApplicationInfo {
        DiagnosticApplicationInfo(
            version: DiagnosticVersionValue("0.9.2") ?? .unknown,
            build: DiagnosticVersionValue("1") ?? .unknown
        )
    }

    private var systemInfo: DiagnosticSystemInfo {
        DiagnosticSystemInfo(
            macOSVersion: DiagnosticVersionValue("26.5.1") ?? .unknown,
            architecture: .arm64
        )
    }

    private func makeBuilder(
        fixture: Fixture,
        reader: StubDiagnosticEventReader
    ) -> DefaultDiagnosticReportBuilder {
        DefaultDiagnosticReportBuilder(
            eventReader: reader,
            application: applicationInfo,
            system: systemInfo,
            identifierGenerator: FixedDiagnosticReportIDGenerator(),
            fileWriter: FileDiagnosticReportStore(
                directory: fixture.directory
            )
        )
    }

    private func diagnosticEvent(at timestamp: Date) -> DiagnosticEvent {
        DiagnosticEvent(
            timestamp: timestamp,
            level: .error,
            component: .chromeReader,
            stage: .sourceRead,
            outcome: .failed,
            direction: .chromeToSafari,
            source: .chromeAccount,
            errorType: .authorization,
            errorCode: .accessDenied,
            durationMilliseconds: 184,
            counts: DiagnosticCounts(bookmarks: 120, folders: 18)
        )
    }
}

private actor StubDiagnosticEventReader: DiagnosticEventReading {
    private let storedEvents: [DiagnosticEvent]
    private let error: DiagnosticEventStoreError?
    private(set) var requestedLimit: Int?

    init(events: [DiagnosticEvent]) {
        storedEvents = events
        error = nil
    }

    init(error: DiagnosticEventStoreError) {
        storedEvents = []
        self.error = error
    }

    func recentEvents(limit: Int, now: Date) throws -> [DiagnosticEvent] {
        requestedLimit = limit
        if let error { throw error }
        return Array(storedEvents.suffix(max(0, limit)))
    }
}

nonisolated private struct FixedDiagnosticReportIDGenerator:
    DiagnosticReportIDGenerating
{
    func makeID() throws -> DiagnosticReportID {
        guard let identifier = DiagnosticReportID("BB-A73F29") else {
            throw DiagnosticReportGenerationError.identifierGenerationFailed
        }
        return identifier
    }
}

private struct Fixture: Sendable {
    let directory: URL
    let now = Date(timeIntervalSince1970: 1_786_464_000)

    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(
            path: "bb-diagnostic-report-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }
}
