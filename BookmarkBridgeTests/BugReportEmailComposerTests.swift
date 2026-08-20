//
//  BugReportEmailComposerTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("Bug report e-mail preparation")
@MainActor
struct BugReportEmailComposerTests {
    @Test("Prepares the support recipient, subject, body and attachment")
    func preparesAttachmentDraft() throws {
        let attachment = StubAttachmentOpener(result: true)
        let mailto = StubMailtoOpener(result: true)
        let clipboard = StubClipboardWriter(result: true)
        let composer = DefaultBugReportEmailComposer(
            attachmentOpener: attachment,
            mailtoOpener: mailto,
            clipboard: clipboard
        )
        let artifact = try makeArtifact()

        let outcome = composer.composeEmail(for: artifact, copy: emailCopy)

        #expect(outcome == .attachmentDraftOpened)
        let draft = try #require(attachment.receivedDraft)
        #expect(draft.recipient == "contact@bookmarkbridge.fr")
        #expect(draft.subject == "[BookmarkBridge][BB-A73F29] Signalement de bug")
        #expect(draft.attachmentURL == artifact.fileURL)
        #expect(draft.attachmentBody.contains(emailCopy.body))
        #expect(draft.attachmentBody.contains(emailCopy.attachmentNotice))
        #expect(mailto.receivedDraft == nil)
        #expect(clipboard.receivedText == nil)
    }

    @Test("Falls back to clipboard and the default mail client")
    func fallsBackWithoutAttachment() throws {
        let attachment = StubAttachmentOpener(result: false)
        let mailto = StubMailtoOpener(result: true)
        let clipboard = StubClipboardWriter(result: true)
        let composer = DefaultBugReportEmailComposer(
            attachmentOpener: attachment,
            mailtoOpener: mailto,
            clipboard: clipboard
        )
        let artifact = try makeArtifact()

        let outcome = composer.composeEmail(for: artifact, copy: emailCopy)

        #expect(outcome == .fallbackDraftOpened(reportCopied: true))
        #expect(clipboard.receivedText == artifact.text)
        let draft = try #require(mailto.receivedDraft)
        #expect(draft.fallbackBody.contains("copié dans le presse-papiers"))
        #expect(draft.fallbackBody.contains("Collez-le sous ce message"))
    }

    @Test("Reports an unavailable mail client without ever sending")
    func reportsUnavailableMailClient() throws {
        let attachment = StubAttachmentOpener(result: false)
        let mailto = StubMailtoOpener(result: false)
        let clipboard = StubClipboardWriter(result: true)
        let composer = DefaultBugReportEmailComposer(
            attachmentOpener: attachment,
            mailtoOpener: mailto,
            clipboard: clipboard
        )

        let outcome = composer.composeEmail(
            for: try makeArtifact(),
            copy: emailCopy
        )

        #expect(outcome == .unavailable(reportCopied: true))
        #expect(mailto.receivedDraft != nil)
    }

    @Test("Automatically generated e-mail fields contain no private data")
    func generatedFieldsArePrivacySafe() throws {
        let draft = BugReportEmailDraftBuilder().makeDraft(
            for: try makeArtifact(),
            copy: emailCopy
        )
        let generatedFields = [
            draft.recipient,
            draft.subject,
            draft.attachmentBody,
            draft.fallbackBody,
        ].joined(separator: "\n")

        for forbidden in [
            "https://private.example/favorite",
            "Titre favori privé",
            "Dossier personnel",
            "BRICKS PRO",
            "/Users/tester",
        ] {
            #expect(!generatedFields.localizedCaseInsensitiveContains(forbidden))
        }
    }

    @Test("Includes the report in the body when clipboard copying fails")
    func includesInlineReportWhenClipboardFails() throws {
        let mailto = StubMailtoOpener(result: true)
        let composer = DefaultBugReportEmailComposer(
            attachmentOpener: StubAttachmentOpener(result: false),
            mailtoOpener: mailto,
            clipboard: StubClipboardWriter(result: false)
        )
        let artifact = try makeArtifact()

        let outcome = composer.composeEmail(for: artifact, copy: emailCopy)

        #expect(outcome == .fallbackDraftOpened(reportCopied: false))
        let draft = try #require(mailto.receivedDraft)
        #expect(draft.fallbackBody.contains(emailCopy.inlineReportNotice))
        #expect(draft.fallbackBody.contains(artifact.text))
        #expect(!draft.fallbackBody.contains(emailCopy.clipboardNotice))
    }

    private var emailCopy: BugReportEmailCopy {
        BugReportEmailCopy(
            subject: "[BookmarkBridge][BB-A73F29] Signalement de bug",
            body: "Bonjour\nReport BB-A73F29",
            attachmentNotice: "Le rapport est joint.",
            clipboardNotice: "copié dans le presse-papiers. Collez-le sous ce message",
            inlineReportNotice: "Rapport inclus ci-dessous.",
            privacyNotice: "Aucune donnée personnelle."
        )
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
            context: DiagnosticContext(
                direction: .chromeToSafari,
                stage: .sourceRead,
                errorType: .authorization,
                errorCode: .accessDenied
            ),
            events: []
        )
        return DiagnosticReportArtifact(
            report: report,
            text: "report_id=BB-A73F29\nprivate_payload_is_already_filtered=true",
            fileURL: URL(filePath: "/private/tmp/BookmarkBridge-BB-A73F29.txt")
        )
    }
}

@MainActor
private final class StubAttachmentOpener: BugReportAttachmentEmailOpening {
    private let result: Bool
    private(set) var receivedDraft: BugReportEmailDraft?

    init(result: Bool) {
        self.result = result
    }

    func openDraftWithAttachment(_ draft: BugReportEmailDraft) -> Bool {
        receivedDraft = draft
        return result
    }
}

@MainActor
private final class StubMailtoOpener: BugReportMailtoOpening {
    private let result: Bool
    private(set) var receivedDraft: BugReportEmailDraft?

    init(result: Bool) {
        self.result = result
    }

    func openMailtoDraft(_ draft: BugReportEmailDraft) -> Bool {
        receivedDraft = draft
        return result
    }
}

@MainActor
private final class StubClipboardWriter: BugReportClipboardWriting {
    private let result: Bool
    private(set) var receivedText: String?

    init(result: Bool) {
        self.result = result
    }

    func copyReport(_ text: String) -> Bool {
        receivedText = text
        return result
    }
}
