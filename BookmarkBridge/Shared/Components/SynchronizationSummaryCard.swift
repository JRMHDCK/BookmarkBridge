//
//  SynchronizationSummaryCard.swift
//  BookmarkBridge
//

import SwiftUI

struct SynchronizationSummaryCard<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        StatusCard(
            "Prévisualisation de la synchronisation",
            systemImage: "arrow.triangle.2.circlepath"
        ) {
            content
        }
    }
}
