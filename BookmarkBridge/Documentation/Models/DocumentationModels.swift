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

    var systemImage: String {
        switch self {
        case .introduction: "sparkles"
        case .installation: "square.and.arrow.down"
        case .configuration: "gearshape"
        case .safari: "safari"
        case .chrome: "globe"
        case .synchronization: "arrow.triangle.2.circlepath"
        case .conflicts: "arrow.triangle.branch"
        case .chromeProfiles: "person.crop.circle.badge.checkmark"
        case .history: "clock.arrow.circlepath"
        case .backups: "externaldrive.badge.timemachine"
        case .faq: "questionmark.bubble"
        case .troubleshooting: "wrench.and.screwdriver"
        case .glossary: "text.book.closed"
        }
    }
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
    let systemImage: String
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
