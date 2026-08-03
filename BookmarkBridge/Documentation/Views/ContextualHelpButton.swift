//
//  ContextualHelpButton.swift
//  BookmarkBridge
//

import SwiftUI

struct ContextualHelpButton: View {
    @Environment(DocumentationRouter.self) private var router

    let pageID: HelpPageID

    var body: some View {
        Button {
            router.request(pageID)
        } label: {
            Label(
                DocumentationText.value("help.contextual.button"),
                systemImage: "questionmark.circle"
            )
        }
        .help(
            DocumentationText.formatted(
                "help.contextual.tooltip",
                DocumentationText.value(pageID.titleKey)
            )
        )
        .accessibilityLabel(
            DocumentationText.formatted(
                "help.contextual.accessibility",
                DocumentationText.value(pageID.titleKey)
            )
        )
    }
}
