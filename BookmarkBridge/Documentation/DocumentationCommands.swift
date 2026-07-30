//
//  DocumentationCommands.swift
//  BookmarkBridge
//

import SwiftUI

struct DocumentationCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openURL) private var openURL

    let router: DocumentationRouter

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(
                DocumentationText.value("menu.about")
            ) {
                openWindow(id: DocumentationWindow.about)
            }
        }

        CommandGroup(replacing: .help) {
            Button(
                DocumentationText.value("menu.helpCenter")
            ) {
                router.request(.introduction)
                openWindow(id: DocumentationWindow.helpCenter)
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
                openWindow(id: DocumentationWindow.whatsNew)
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
