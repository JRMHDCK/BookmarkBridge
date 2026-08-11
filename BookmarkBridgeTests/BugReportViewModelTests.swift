//
//  BugReportViewModelTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("Bug report user journey")
@MainActor
struct BugReportViewModelTests {
    @Test("Builds a contextual report and prepares an e-mail draft")
    func preparesContextualDraft() async throws {
        let artifact = try makeArtifact()
        let builder = StubBugReportBuilder(artifact: artifact)
        let composer = StubBugReportEmailComposer(
            outcome: .attachmentDraftOpened
        )
        let now = Date(timeIntervalSince1970: 1_786_464_000)
        let model = BugReportViewModel(
            reportBuilder: builder,
            emailComposer: composer,
            nowProvider: { now }
        )
        let context = DiagnosticContext(
            direction: .chromeToSafari,
            stage: .sourceRead,
            errorType: .authorization,
            errorCode: .accessDenied
        )

        await model.report(origin: .contextualError, context: context)

        #expect(model.state == .draftOpened(artifact.report.id))
        #expect(await builder.receivedOrigin == .contextualError)
        #expect(await builder.receivedContext == context)
        #expect(await builder.receivedDate == now)
        #expect(composer.receivedArtifact == artifact)
        #expect(composer.receivedCopy?.subject.contains("BB-A73F29") == true)
    }

    @Test("Builds a manual report from the help center")
    func preparesHelpCenterDraft() async throws {
        let artifact = try makeArtifact()
        let builder = StubBugReportBuilder(artifact: artifact)
        let model = BugReportViewModel(
            reportBuilder: builder,
            emailComposer: StubBugReportEmailComposer(
                outcome: .fallbackDraftOpened(reportCopied: true)
            )
        )

        await model.report(
            origin: .helpCenter,
            context: DiagnosticContext()
        )

        #expect(model.state == .draftOpened(artifact.report.id))
        #expect(await builder.receivedOrigin == .helpCenter)
    }

    @Test("Exposes report generation and mail client failures")
    func exposesFailures() async throws {
        let generationFailure = BugReportViewModel(
            reportBuilder: StubBugReportBuilder(error: StubFailure.failed),
            emailComposer: StubBugReportEmailComposer(
                outcome: .attachmentDraftOpened
            )
        )

        await generationFailure.report(
            origin: .helpCenter,
            context: DiagnosticContext()
        )
        #expect(generationFailure.failure == .reportGeneration)
        generationFailure.dismissFailure()
        #expect(generationFailure.state == .idle)

        let mailFailure = BugReportViewModel(
            reportBuilder: StubBugReportBuilder(
                artifact: try makeArtifact()
            ),
            emailComposer: StubBugReportEmailComposer(
                outcome: .unavailable(reportCopied: true)
            )
        )
        await mailFailure.report(
            origin: .helpCenter,
            context: DiagnosticContext()
        )
        #expect(mailFailure.failure == .mailClientUnavailable)
    }

    private func makeArtifact() throws -> DiagnosticReportArtifact {
        let identifier = try #require(DiagnosticReportID("BB-A73F29"))
        let report = DiagnosticReport(
            id: identifier,
            createdAt: Date(timeIntervalSince1970: 1_786_464_000),
            origin: .contextualError,
            application: DiagnosticApplicationInfo(
                version: DiagnosticVersionValue("0.9.2") ?? .unknown,
                build: DiagnosticVersionValue("1") ?? .unknown
            ),
            system: DiagnosticSystemInfo(
                macOSVersion: DiagnosticVersionValue("26.5.1") ?? .unknown,
                architecture: .arm64
            ),
            context: DiagnosticContext(),
            events: []
        )
        return DiagnosticReportArtifact(
            report: report,
            text: "report_id=BB-A73F29",
            fileURL: URL(filePath: "/private/tmp/BookmarkBridge-BB-A73F29.txt")
        )
    }
}

private actor StubBugReportBuilder: DiagnosticReportBuilding {
    private let artifact: DiagnosticReportArtifact?
    private let error: (any Error)?
    private(set) var receivedOrigin: DiagnosticReportOrigin?
    private(set) var receivedContext: DiagnosticContext?
    private(set) var receivedDate: Date?

    init(artifact: DiagnosticReportArtifact) {
        self.artifact = artifact
        error = nil
    }

    init(error: any Error) {
        artifact = nil
        self.error = error
    }

    func build(
        origin: DiagnosticReportOrigin,
        context: DiagnosticContext,
        now: Date
    ) throws -> DiagnosticReportArtifact {
        receivedOrigin = origin
        receivedContext = context
        receivedDate = now
        if let error { throw error }
        guard let artifact else { throw StubFailure.failed }
        return artifact
    }
}

@MainActor
private final class StubBugReportEmailComposer: BugReportEmailComposing {
    private let outcome: BugReportEmailCompositionOutcome
    private(set) var receivedArtifact: DiagnosticReportArtifact?
    private(set) var receivedCopy: BugReportEmailCopy?

    init(outcome: BugReportEmailCompositionOutcome) {
        self.outcome = outcome
    }

    func composeEmail(
        for artifact: DiagnosticReportArtifact,
        copy: BugReportEmailCopy
    ) -> BugReportEmailCompositionOutcome {
        receivedArtifact = artifact
        receivedCopy = copy
        return outcome
    }
}

nonisolated private enum StubFailure: Error, Sendable {
    case failed
}
