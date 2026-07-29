//
//  StateViews.swift
//  BookmarkBridge
//

import SwiftUI

struct EmptyStateView: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let systemImage: String

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: systemImage,
            description: Text(message)
        )
        .accessibilityElement(children: .combine)
    }
}

struct ErrorStateView: View {
    let message: String
    var retryTitle: LocalizedStringKey = "Réessayer"
    let onRetry: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.Palette.error)
            if let onRetry {
                SecondaryActionButton(retryTitle, action: onRetry)
            }
        }
        .accessibilityElement(children: .contain)
    }
}
