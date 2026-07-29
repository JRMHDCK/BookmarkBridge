//
//  SynchronizationSummaryCard.swift
//  BookmarkBridge
//

import SwiftUI

struct SynchronizationSummaryCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(
        _ title: String = "Prévisualisation de la synchronisation",
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        StatusCard(
            title,
            systemImage: "arrow.triangle.2.circlepath"
        ) {
            content
        }
    }
}
