//
//  BugReportEmailComposer.swift
//  BookmarkBridge
//

import Foundation

nonisolated struct BugReportEmailDraft: Hashable, Sendable {
    let recipient: String
    let subject: String
    let attachmentBody: String
    let fallbackBody: String
    let attachmentURL: URL
    let reportText: String
}

nonisolated struct BugReportEmailCopy: Hashable, Sendable {
    let subject: String
    let body: String
    let attachmentNotice: String
    let clipboardNotice: String
    let inlineReportNotice: String
    let privacyNotice: String
}

nonisolated struct BugReportEmailDraftBuilder: Sendable {
    static let supportAddress = "contact@bookmarkbridge.fr"

    func makeDraft(
        for artifact: DiagnosticReportArtifact,
        copy: BugReportEmailCopy
    ) -> BugReportEmailDraft {
        return BugReportEmailDraft(
            recipient: Self.supportAddress,
            subject: copy.subject,
            attachmentBody: copy.body + "\n\n" + copy.attachmentNotice
                + "\n\n" + copy.privacyNotice,
            fallbackBody: copy.body + "\n\n" + copy.clipboardNotice
                + "\n\n" + copy.privacyNotice,
            attachmentURL: artifact.fileURL,
            reportText: artifact.text
        )
    }

    func includingInlineReport(
        in draft: BugReportEmailDraft,
        copy: BugReportEmailCopy
    ) -> BugReportEmailDraft {
        BugReportEmailDraft(
            recipient: draft.recipient,
            subject: draft.subject,
            attachmentBody: draft.attachmentBody,
            fallbackBody: copy.body + "\n\n" + copy.inlineReportNotice
                + "\n\n" + copy.privacyNotice + "\n\n---\n"
                + draft.reportText,
            attachmentURL: draft.attachmentURL,
            reportText: draft.reportText
        )
    }
}

nonisolated enum BugReportEmailCompositionOutcome: Equatable, Sendable {
    case attachmentDraftOpened
    case fallbackDraftOpened(reportCopied: Bool)
    case unavailable(reportCopied: Bool)
}

nonisolated protocol BugReportEmailComposing: Sendable {
    @MainActor
    func composeEmail(
        for artifact: DiagnosticReportArtifact,
        copy: BugReportEmailCopy
    ) -> BugReportEmailCompositionOutcome
}

nonisolated protocol BugReportAttachmentEmailOpening: Sendable {
    @MainActor
    func openDraftWithAttachment(_ draft: BugReportEmailDraft) -> Bool
}

nonisolated protocol BugReportMailtoOpening: Sendable {
    @MainActor
    func openMailtoDraft(_ draft: BugReportEmailDraft) -> Bool
}

nonisolated protocol BugReportClipboardWriting: Sendable {
    @MainActor
    func copyReport(_ text: String) -> Bool
}

/// Coordinates draft preparation only. Sending always remains an explicit user
/// action in the selected mail client.
nonisolated struct DefaultBugReportEmailComposer: BugReportEmailComposing {
    private let attachmentOpener: any BugReportAttachmentEmailOpening
    private let mailtoOpener: any BugReportMailtoOpening
    private let clipboard: any BugReportClipboardWriting
    private let draftBuilder: BugReportEmailDraftBuilder

    init(
        attachmentOpener: any BugReportAttachmentEmailOpening,
        mailtoOpener: any BugReportMailtoOpening,
        clipboard: any BugReportClipboardWriting,
        draftBuilder: BugReportEmailDraftBuilder = BugReportEmailDraftBuilder()
    ) {
        self.attachmentOpener = attachmentOpener
        self.mailtoOpener = mailtoOpener
        self.clipboard = clipboard
        self.draftBuilder = draftBuilder
    }

    @MainActor
    func composeEmail(
        for artifact: DiagnosticReportArtifact,
        copy: BugReportEmailCopy
    ) -> BugReportEmailCompositionOutcome {
        let draft = draftBuilder.makeDraft(for: artifact, copy: copy)
        if attachmentOpener.openDraftWithAttachment(draft) {
            return .attachmentDraftOpened
        }

        let copied = clipboard.copyReport(draft.reportText)
        let fallbackDraft = copied
            ? draft
            : draftBuilder.includingInlineReport(in: draft, copy: copy)
        if mailtoOpener.openMailtoDraft(fallbackDraft) {
            return .fallbackDraftOpened(reportCopied: copied)
        }
        return .unavailable(reportCopied: copied)
    }
}
