//
//  StatusCard.swift
//  BookmarkBridge
//

import SwiftUI

/// Shared card shell for status-oriented content.
struct StatusCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    init(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Theme.Spacing.xs)
        } label: {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .symbolRenderingMode(.hierarchical)
        }
    }
}
