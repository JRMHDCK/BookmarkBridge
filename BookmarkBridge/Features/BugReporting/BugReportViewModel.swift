//
//  BugReportViewModel.swift
//  BookmarkBridge
//

import Foundation
import Observation

@MainActor
@Observable
final class BugReportViewModel {
    nonisolated enum Failure: Equatable, Sendable {
        case reportGeneration
        case mailClientUnavailable
    }

    nonisolated enum State: Equatable, Sendable {
        case idle
        case preparing
        case draftOpened(DiagnosticReportID)
        case failed(Failure)
    }

    private(set) var state: State = .idle

    var isPreparing: Bool {
        state == .preparing
    }

    var failure: Failure? {
        guard case .failed(let failure) = state else { return nil }
        return failure
    }

    var isDraftOpened: Bool {
        guard case .draftOpened = state else { return false }
        return true
    }

    private let reportBuilder: any DiagnosticReportBuilding
    private let emailComposer: any BugReportEmailComposing
    private let nowProvider: @MainActor @Sendable () -> Date

    init(
        reportBuilder: any DiagnosticReportBuilding,
        emailComposer: any BugReportEmailComposing,
        nowProvider: @escaping @MainActor @Sendable () -> Date = Date.init
    ) {
        self.reportBuilder = reportBuilder
        self.emailComposer = emailComposer
        self.nowProvider = nowProvider
    }

    func report(
        origin: DiagnosticReportOrigin,
        context: DiagnosticContext
    ) async {
        guard !isPreparing else { return }
        state = .preparing
        do {
            let artifact = try await reportBuilder.build(
                origin: origin,
                context: context,
                now: nowProvider()
            )
            let copy = BugReportEmailCopy.localized(for: artifact.report)
            switch emailComposer.composeEmail(for: artifact, copy: copy) {
            case .attachmentDraftOpened, .fallbackDraftOpened:
                state = .draftOpened(artifact.report.id)
            case .unavailable:
                state = .failed(.mailClientUnavailable)
            }
        } catch {
            state = .failed(.reportGeneration)
        }
    }

    func dismissFailure() {
        guard failure != nil else { return }
        state = .idle
    }
}

extension BugReportEmailCopy {
    @MainActor
    static func localized(for report: DiagnosticReport) -> BugReportEmailCopy {
        let unavailable = DocumentationText.value("bugReport.value.unavailable")
        let direction = report.context.direction?.rawValue ?? unavailable
        let errorType = report.context.errorType?.rawValue ?? unavailable
        let errorCode = report.context.errorCode?.rawValue ?? unavailable
        return BugReportEmailCopy(
            subject: DocumentationText.formatted(
                "bugReport.email.subject",
                report.id.rawValue
            ),
            body: DocumentationText.formatted(
                "bugReport.email.body",
                report.id.rawValue,
                report.application.version.rawValue,
                report.application.build.rawValue,
                report.system.macOSVersion.rawValue,
                report.system.architecture.rawValue,
                direction,
                report.context.stage.rawValue,
                errorType,
                errorCode
            ),
            attachmentNotice: DocumentationText.value(
                "bugReport.email.attachmentNotice"
            ),
            clipboardNotice: DocumentationText.value(
                "bugReport.email.clipboardNotice"
            ),
            inlineReportNotice: DocumentationText.value(
                "bugReport.email.inlineNotice"
            ),
            privacyNotice: DocumentationText.value(
                "bugReport.email.privacyNotice"
            )
        )
    }
}

#if DEBUG
nonisolated struct UITestBugReportEmailComposer: BugReportEmailComposing {
    @MainActor
    func composeEmail(
        for artifact: DiagnosticReportArtifact,
        copy: BugReportEmailCopy
    ) -> BugReportEmailCompositionOutcome {
        .attachmentDraftOpened
    }
}
#endif
