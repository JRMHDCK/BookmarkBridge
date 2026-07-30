//
//  HelpCatalog.swift
//  BookmarkBridge
//

import Foundation

enum HelpCatalog {
    static let pages: [HelpPage] = [
        HelpPage(
            id: .introduction,
            blocks: [
                .paragraph("help.introduction.overview"),
                .heading("help.introduction.principles.title"),
                .bullets([
                    "help.introduction.principles.preview",
                    "help.introduction.principles.local",
                    "help.introduction.principles.backup",
                ]),
                .note(
                    titleKey: "help.callout.readonly.title",
                    bodyKey: "help.callout.readonly.body",
                    systemImage: "lock.shield"
                ),
            ]
        ),
        HelpPage(
            id: .installation,
            blocks: [
                .paragraph("help.installation.requirements"),
                .heading("help.installation.steps.title"),
                .steps([
                    "help.installation.step.move",
                    "help.installation.step.open",
                    "help.installation.step.permissions",
                ]),
                .note(
                    titleKey: "help.installation.compatibility.title",
                    bodyKey: "help.installation.compatibility.body",
                    systemImage: "macbook"
                ),
            ]
        ),
        HelpPage(
            id: .configuration,
            blocks: [
                .paragraph("help.configuration.overview"),
                .heading("help.configuration.permissions.title"),
                .steps([
                    "help.configuration.permission.safari",
                    "help.configuration.permission.chrome",
                    "help.configuration.permission.verify",
                ]),
                .note(
                    titleKey: "help.configuration.privacy.title",
                    bodyKey: "help.configuration.privacy.body",
                    systemImage: "hand.raised"
                ),
            ]
        ),
        HelpPage(
            id: .safari,
            blocks: [
                .paragraph("help.safari.overview"),
                .heading("help.safari.authorization.title"),
                .steps([
                    "help.safari.authorization.open",
                    "help.safari.authorization.select",
                    "help.safari.authorization.confirm",
                ]),
                .note(
                    titleKey: "help.safari.readonly.title",
                    bodyKey: "help.safari.readonly.body",
                    systemImage: "eye"
                ),
            ]
        ),
        HelpPage(
            id: .chrome,
            blocks: [
                .paragraph("help.chrome.overview"),
                .heading("help.chrome.authorization.title"),
                .steps([
                    "help.chrome.authorization.open",
                    "help.chrome.authorization.select",
                    "help.chrome.authorization.profile",
                ]),
                .note(
                    titleKey: "help.chrome.closed.title",
                    bodyKey: "help.chrome.closed.body",
                    systemImage: "xmark.app"
                ),
            ]
        ),
        HelpPage(
            id: .synchronization,
            blocks: [
                .paragraph("help.synchronization.overview"),
                .heading("help.synchronization.workflow.title"),
                .steps([
                    "help.synchronization.step.reload",
                    "help.synchronization.step.review",
                    "help.synchronization.step.close",
                    "help.synchronization.step.confirm",
                    "help.synchronization.step.verify",
                ]),
                .note(
                    titleKey: "help.synchronization.additive.title",
                    bodyKey: "help.synchronization.additive.body",
                    systemImage: "plus.circle"
                ),
            ]
        ),
        HelpPage(
            id: .conflicts,
            blocks: [
                .paragraph("help.conflicts.overview"),
                .heading("help.conflicts.behavior.title"),
                .bullets([
                    "help.conflicts.behavior.preview",
                    "help.conflicts.behavior.readonly",
                    "help.conflicts.behavior.choice",
                ]),
                .note(
                    titleKey: "help.conflicts.safety.title",
                    bodyKey: "help.conflicts.safety.body",
                    systemImage: "exclamationmark.shield"
                ),
            ]
        ),
        HelpPage(
            id: .chromeProfiles,
            blocks: [
                .paragraph("help.profiles.overview"),
                .heading("help.profiles.selection.title"),
                .bullets([
                    "help.profiles.selection.local",
                    "help.profiles.selection.account",
                    "help.profiles.selection.multiple",
                ]),
                .note(
                    titleKey: "help.profiles.ambiguous.title",
                    bodyKey: "help.profiles.ambiguous.body",
                    systemImage: "person.crop.circle.badge.exclamationmark"
                ),
            ]
        ),
        HelpPage(
            id: .history,
            blocks: [
                .paragraph("help.history.overview"),
                .heading("help.history.available.title"),
                .bullets([
                    "help.history.available.result",
                    "help.history.available.backup",
                    "help.history.available.refresh",
                ]),
                .note(
                    titleKey: "help.history.beta.title",
                    bodyKey: "help.history.beta.body",
                    systemImage: "clock"
                ),
            ]
        ),
        HelpPage(
            id: .backups,
            blocks: [
                .paragraph("help.backups.overview"),
                .heading("help.backups.restore.title"),
                .steps([
                    "help.backups.restore.close",
                    "help.backups.restore.open",
                    "help.backups.restore.confirm",
                    "help.backups.restore.verify",
                ]),
                .note(
                    titleKey: "help.backups.scope.title",
                    bodyKey: "help.backups.scope.body",
                    systemImage: "lock.doc"
                ),
            ]
        ),
        HelpPage(
            id: .faq,
            blocks: [
                .question(
                    questionKey: "help.faq.safari.question",
                    answerKey: "help.faq.safari.answer"
                ),
                .question(
                    questionKey: "help.faq.chromeEmpty.question",
                    answerKey: "help.faq.chromeEmpty.answer"
                ),
                .question(
                    questionKey: "help.faq.duplicateFolder.question",
                    answerKey: "help.faq.duplicateFolder.answer"
                ),
                .question(
                    questionKey: "help.faq.sync.question",
                    answerKey: "help.faq.sync.answer"
                ),
                .question(
                    questionKey: "help.faq.delete.question",
                    answerKey: "help.faq.delete.answer"
                ),
                .question(
                    questionKey: "help.faq.profiles.question",
                    answerKey: "help.faq.profiles.answer"
                ),
                .question(
                    questionKey: "help.faq.restore.question",
                    answerKey: "help.faq.restore.answer"
                ),
                .question(
                    questionKey: "help.faq.missing.question",
                    answerKey: "help.faq.missing.answer"
                ),
            ]
        ),
        HelpPage(
            id: .troubleshooting,
            blocks: [
                .heading("help.troubleshooting.permission.title"),
                .paragraph("help.troubleshooting.permission.body"),
                .heading("help.troubleshooting.chrome.title"),
                .paragraph("help.troubleshooting.chrome.body"),
                .heading("help.troubleshooting.empty.title"),
                .paragraph("help.troubleshooting.empty.body"),
                .heading("help.troubleshooting.retry.title"),
                .paragraph("help.troubleshooting.retry.body"),
                .note(
                    titleKey: "help.troubleshooting.safe.title",
                    bodyKey: "help.troubleshooting.safe.body",
                    systemImage: "checkmark.shield"
                ),
            ]
        ),
        HelpPage(
            id: .glossary,
            blocks: [
                .question(
                    questionKey: "help.glossary.preview.term",
                    answerKey: "help.glossary.preview.definition"
                ),
                .question(
                    questionKey: "help.glossary.profile.term",
                    answerKey: "help.glossary.profile.definition"
                ),
                .question(
                    questionKey: "help.glossary.backup.term",
                    answerKey: "help.glossary.backup.definition"
                ),
                .question(
                    questionKey: "help.glossary.additive.term",
                    answerKey: "help.glossary.additive.definition"
                ),
                .question(
                    questionKey: "help.glossary.securityScope.term",
                    answerKey: "help.glossary.securityScope.definition"
                ),
                .question(
                    questionKey: "help.glossary.bse.term",
                    answerKey: "help.glossary.bse.definition"
                ),
            ]
        ),
    ]

    static func page(_ id: HelpPageID) -> HelpPage {
        pages.first(where: { $0.id == id })
            ?? HelpPage(id: .introduction, blocks: [])
    }

    static func index(of id: HelpPageID) -> Int {
        pages.firstIndex(where: { $0.id == id }) ?? 0
    }

    static func page(before id: HelpPageID) -> HelpPage? {
        let index = index(of: id)
        guard index > pages.startIndex else { return nil }
        return pages[index - 1]
    }

    static func page(after id: HelpPageID) -> HelpPage? {
        let index = index(of: id)
        guard index < pages.index(before: pages.endIndex) else {
            return nil
        }
        return pages[index + 1]
    }

    static func search(_ query: String) -> [HelpPage] {
        let normalized = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !normalized.isEmpty else { return pages }
        return pages.filter { page in
            page.searchableKeys.contains { key in
                DocumentationText.value(key).localizedCaseInsensitiveContains(
                    normalized
                )
            }
        }
    }
}
