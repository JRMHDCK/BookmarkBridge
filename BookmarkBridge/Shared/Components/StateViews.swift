//
//  StateViews.swift
//  BookmarkBridge
//

import SwiftUI

struct LoadingStateView: View {
    let message: String

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            ProgressView()
                .controlSize(.small)
            Text(message)
                .foregroundStyle(.secondary)
        }
        .font(.callout)
        .accessibilityElement(children: .combine)
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
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
    var retryTitle: String = DocumentationText.value("action.retry")
    let onRetry: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            UserFacingErrorDetails(
                presentation:
                    UserFacingErrorPresentation.presentation(
                        for: message
                    )
            )
            if let onRetry {
                SecondaryActionButton(retryTitle, action: onRetry)
                    .help(
                        DocumentationText.value(
                            "error.retry.tooltip"
                        )
                    )
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct SuccessStateView: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "checkmark.circle")
            .foregroundStyle(Theme.Palette.green)
            .symbolRenderingMode(.hierarchical)
            .font(.callout)
            .accessibilityElement(children: .combine)
    }
}
