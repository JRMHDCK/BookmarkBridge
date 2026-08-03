//
//  DocumentationCommands.swift
//  BookmarkBridge
//

import SwiftUI

struct DocumentationCommands: Commands {
    @Environment(\.openURL) private var openURL

    let router: DocumentationRouter

    var body: some Commands {
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
        guard let url = Bundle.main.url(
            forResource: "BookmarkBridge-User-Guide",
            withExtension: "pdf"
        ) else { return }
        openURL(url)
    }
}
