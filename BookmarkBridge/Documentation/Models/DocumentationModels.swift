//
//  DocumentationModels.swift
//  BookmarkBridge
//

import Foundation

enum HelpPageID: String, CaseIterable, Identifiable, Sendable {
    case introduction
    case installation
    case configuration
    case safari
    case chrome
    case synchronization
    case conflicts
    case chromeProfiles
    case history
    case backups
    case faq
    case troubleshooting
    case glossary

    var id: Self { self }

    var titleKey: String {
        "help.page.\(rawValue).title"
    }

    var subtitleKey: String {
        "help.page.\(rawValue).subtitle"
    }

    var icon: DocumentationIcon {
        switch self {
        case .introduction: .system("sparkles")
        case .installation: .system("square.and.arrow.down")
        case .configuration: .system("gearshape")
        case .safari: .browser(.safari)
        case .chrome, .chromeProfiles: .browser(.chrome)
        case .synchronization: .system("arrow.triangle.2.circlepath")
        case .conflicts: .system("arrow.triangle.branch")
        case .history: .system("clock.arrow.circlepath")
        case .backups: .system("externaldrive.badge.timemachine")
        case .faq: .system("questionmark.bubble")
        case .troubleshooting: .system("wrench.and.screwdriver")
        case .glossary: .system("text.book.closed")
        }
    }
}

enum DocumentationIcon: Sendable {
    case system(String)
    case browser(Browser)
}

enum HelpBlock: Sendable {
    case heading(String)
    case paragraph(String)
    case bullets([String])
    case steps([String])
    case note(titleKey: String, bodyKey: String, systemImage: String)
    case question(questionKey: String, answerKey: String)

    var searchableKeys: [String] {
        switch self {
        case .heading(let key), .paragraph(let key):
            [key]
        case .bullets(let keys), .steps(let keys):
            keys
        case .note(let titleKey, let bodyKey, _):
            [titleKey, bodyKey]
        case .question(let questionKey, let answerKey):
            [questionKey, answerKey]
        }
    }
}

struct HelpPage: Identifiable, Sendable {
    let id: HelpPageID
    let blocks: [HelpBlock]

    var searchableKeys: [String] {
        [id.titleKey, id.subtitleKey]
            + blocks.flatMap(\.searchableKeys)
    }
}

struct OnboardingStep: Identifiable, Sendable {
    let id: String
    let titleKey: String
    let bodyKey: String
    let icon: DocumentationIcon
}

struct WhatsNewSection: Identifiable, Sendable {
    let id: String
    let titleKey: String
    let systemImage: String
    let itemKeys: [String]
}

struct WhatsNewRelease: Sendable {
    let version: String
    let build: String
    let sections: [WhatsNewSection]
}
