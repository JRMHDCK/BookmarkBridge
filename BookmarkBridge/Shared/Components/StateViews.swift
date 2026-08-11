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
    var onReportError: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            UserFacingErrorDetails(
                presentation:
                    UserFacingErrorPresentation.presentation(
                        for: message
                    )
            )
            if onRetry != nil || onReportError != nil {
                HStack(spacing: Theme.Spacing.s) {
                    if let onRetry {
                        SecondaryActionButton(retryTitle, action: onRetry)
                            .help(
                                DocumentationText.value(
                                    "error.retry.tooltip"
                                )
                            )
                    }
                    if let onReportError {
                        SecondaryActionButton(
                            DocumentationText.value(
                                "bugReport.action.reportError"
                            ),
                            systemImage: "ladybug",
                            action: onReportError
                        )
                        .help(
                            DocumentationText.value(
                                "bugReport.error.tooltip"
                            )
                        )
                        .accessibilityIdentifier("bug-report.contextual")
                        .accessibilityHint(
                            DocumentationText.value(
                                "bugReport.accessibility.hint"
                            )
                        )
                    }
                }
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
