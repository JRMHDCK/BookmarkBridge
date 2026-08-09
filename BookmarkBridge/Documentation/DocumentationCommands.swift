//
//  DocumentationCommands.swift
//  BookmarkBridge
//

import SwiftUI

struct DocumentationCommands: Commands {
    @Environment(\.openURL) private var openURL

    let router: DocumentationRouter
    let localization: LocalizationController

    var body: some Commands {
        let _ = localization.selectedLanguage
        CommandGroup(replacing: .newItem) { }

        CommandGroup(replacing: .appInfo) {
            Button(
                DocumentationText.value("menu.about")
            ) {
                router.showAbout()
            }
        }

        CommandGroup(replacing: .help) {
            Button(
                DocumentationText.value("menu.helpCenter")
            ) {
                router.request(.introduction)
            }
            .keyboardShortcut("/", modifiers: [.command, .shift])

            Button(
                DocumentationText.value("menu.userGuide")
            ) {
                openUserGuide()
            }

            Divider()

            Button(
                DocumentationText.value("menu.whatsNew")
            ) {
                router.showWhatsNew()
            }
        }
    }

    private func openUserGuide() {
        let language = localization.resolvedLanguage.rawValue
        guard let url = Bundle.main.url(
            forResource: "BookmarkBridge-User-Guide-\(language)",
            withExtension: "pdf"
        ) else { return }
        openURL(url)
    }
}
