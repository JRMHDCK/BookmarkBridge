//
//  PermissionCard.swift
//  BookmarkBridge
//

import SwiftUI

struct PermissionCard<Content: View>: View {
    let statusSymbol: String
    @ViewBuilder let content: Content

    init(
        statusSymbol: String,
        @ViewBuilder content: () -> Content
    ) {
        self.statusSymbol = statusSymbol
        self.content = content()
    }

    var body: some View {
        StatusCard(
            DocumentationText.value("authorization.card.title"),
            systemImage: statusSymbol
        ) {
            content
        }
    }
}
