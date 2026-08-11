//
//  DiagnosticReportBuilder.swift
//  BookmarkBridge
//

import Foundation

nonisolated protocol DiagnosticReportBuilding: Sendable {
    func build(
        origin: DiagnosticReportOrigin,
        context: DiagnosticContext,
        now: Date
    ) async throws -> DiagnosticReportArtifact
}

nonisolated protocol DiagnosticReportIDGenerating: Sendable {
    func makeID() throws -> DiagnosticReportID
}

nonisolated enum DiagnosticReportGenerationError:
    Error,
    Equatable,
    Sendable
{
    case identifierGenerationFailed
    case fileCreationFailed
}

nonisolated struct RandomDiagnosticReportIDGenerator:
    DiagnosticReportIDGenerating
{
    func makeID() throws -> DiagnosticReportID {
        let hexadecimal = (0..<3).map { _ in
            String(format: "%02X", UInt8.random(in: .min ... .max))
        }.joined()
        guard let identifier = DiagnosticReportID("BB-\(hexadecimal)") else {
            throw DiagnosticReportGenerationError.identifierGenerationFailed
        }
        return identifier
    }
}

/// Builds a complete privacy-safe report and prepares its local text file.
actor DefaultDiagnosticReportBuilder: DiagnosticReportBuilding {
    static let eventLimit = 50

    private let eventReader: any DiagnosticEventReading
    private let application: DiagnosticApplicationInfo
    private let system: DiagnosticSystemInfo
    private let identifierGenerator: any DiagnosticReportIDGenerating
    private let renderer: any DiagnosticReportTextRendering
    private let fileWriter: any DiagnosticReportFileWriting

    init(
        eventReader: any DiagnosticEventReading,
        application: DiagnosticApplicationInfo,
        system: DiagnosticSystemInfo,
        identifierGenerator: any DiagnosticReportIDGenerating =
            RandomDiagnosticReportIDGenerator(),
        renderer: any DiagnosticReportTextRendering =
            DiagnosticReportTextRenderer(),
        fileWriter: any DiagnosticReportFileWriting =
            FileDiagnosticReportStore.inTemporaryDirectory()
    ) {
        self.eventReader = eventReader
        self.application = application
        self.system = system
        self.identifierGenerator = identifierGenerator
        self.renderer = renderer
        self.fileWriter = fileWriter
    }

    func build(
        origin: DiagnosticReportOrigin,
        context: DiagnosticContext,
        now: Date
    ) async throws -> DiagnosticReportArtifact {
        let journal = await readJournal(now: now)
        let identifier: DiagnosticReportID
        do {
            identifier = try identifierGenerator.makeID()
        } catch {
            throw DiagnosticReportGenerationError.identifierGenerationFailed
        }
        let report = DiagnosticReport(
            id: identifier,
            createdAt: now,
            origin: origin,
            application: application,
            system: system,
            context: context,
            journalStatus: journal.status,
            events: journal.events
        )
        let text = renderer.render(report)
        let fileURL: URL
        do {
            fileURL = try await fileWriter.write(
                text: text,
                reportID: identifier,
                now: now
            )
        } catch {
            throw DiagnosticReportGenerationError.fileCreationFailed
        }
        return DiagnosticReportArtifact(
            report: report,
            text: text,
            fileURL: fileURL
        )
    }

    private func readJournal(
        now: Date
    ) async -> (status: DiagnosticJournalStatus, events: [DiagnosticEvent]) {
        do {
            let events = try await eventReader.recentEvents(
                limit: Self.eventLimit,
                now: now
            )
            return (.available, events)
        } catch DiagnosticEventStoreError.corruptedData {
            return (.corrupted, [])
        } catch DiagnosticEventStoreError.unsupportedVersion {
            return (.unsupportedVersion, [])
        } catch {
            return (.unavailable, [])
        }
    }
}
