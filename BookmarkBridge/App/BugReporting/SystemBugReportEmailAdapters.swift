//
//  SystemBugReportEmailAdapters.swift
//  BookmarkBridge
//

import AppKit
import Foundation

nonisolated struct SystemBugReportAttachmentEmailOpener:
    BugReportAttachmentEmailOpening
{
    @MainActor
    func openDraftWithAttachment(_ draft: BugReportEmailDraft) -> Bool {
        guard FileManager.default.fileExists(
            atPath: draft.attachmentURL.path(percentEncoded: false)
        ),
        let service = NSSharingService(named: .composeEmail)
        else {
            return false
        }

        let items: [Any] = [draft.attachmentBody, draft.attachmentURL]
        guard service.canPerform(withItems: items) else { return false }
        service.recipients = [draft.recipient]
        service.subject = draft.subject
        service.perform(withItems: items)
        return true
    }
}

nonisolated struct SystemBugReportMailtoOpener: BugReportMailtoOpening {
    @MainActor
    func openMailtoDraft(_ draft: BugReportEmailDraft) -> Bool {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = draft.recipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: draft.subject),
            URLQueryItem(name: "body", value: draft.fallbackBody),
        ]
        guard let url = components.url else { return false }
        return NSWorkspace.shared.open(url)
    }
}

nonisolated struct SystemBugReportClipboardWriter: BugReportClipboardWriting {
    @MainActor
    func copyReport(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }
}

extension DefaultBugReportEmailComposer {
    static func systemDefault() -> DefaultBugReportEmailComposer {
        DefaultBugReportEmailComposer(
            attachmentOpener: SystemBugReportAttachmentEmailOpener(),
            mailtoOpener: SystemBugReportMailtoOpener(),
            clipboard: SystemBugReportClipboardWriter()
        )
    }
}
