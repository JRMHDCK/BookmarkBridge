//
//  UserFacingErrorPresentation.swift
//  BookmarkBridge
//

import SwiftUI

struct UserFacingErrorPresentation: Sendable {
    let titleKey: String
    let descriptionKey: String
    let causeKey: String
    let solutionKey: String

    static let authorization = UserFacingErrorPresentation(
        titleKey: "error.authorization.title",
        descriptionKey: "error.authorization.description",
        causeKey: "error.authorization.cause",
        solutionKey: "error.authorization.solution"
    )

    static func presentation(for message: String) -> Self {
        if containsLocalized(message, keys: [
            "sync.closeBrowsers.error",
            "sync.closeBeforeRestore",
        ]) {
            return preset("chromeRunning")
        }
        if containsLocalized(message, keys: ["error.multipleStores.short"]) {
            return preset("multipleStores")
        }
        if containsLocalized(
            message,
            keys: ["error.bookmarksFileMissing.short"]
        ) {
            return preset("sourceMissing")
        }
        if containsLocalized(message, keys: [
            "error.fileAccessDenied.short",
            "sync.chromeWriteAccess.failure",
        ]) {
            return authorization
        }
        if containsLocalized(message, keys: ["error.fileUnreadable.short"]) {
            return preset("unreadable")
        }
        if containsLocalized(message, keys: ["preview.calculationFailed"]) {
            return preset("preview")
        }
        if containsLocalized(message, keys: ["sync.cancelled"]) {
            return preset("cancelled")
        }
        if containsLocalized(message, keys: [
            "sync.backup.failure",
            "sync.backupBak.failure",
            "sync.failure.backup",
        ]) {
            return preset("backup")
        }
        if containsLocalized(message, keys: [
            "restore.failure.short",
            "sync.failure.restoration",
        ]) {
            return preset("restore")
        }
        if containsLocalized(message, keys: [
            "sync.failure.short",
            "sync.failure.execution",
            "sync.failure.finalValidation",
            "sync.failure.generic",
        ]) {
            return preset("synchronization")
        }
        if containsLocalized(
            message,
            keys: ["error.unsupportedBrowser.short"]
        ) {
            return preset("unsupportedBrowser")
        }
        return preset("generic")
    }

    private static func containsLocalized(
        _ message: String,
        keys: [String]
    ) -> Bool {
        AppLanguage.localizedLanguages.contains { language in
            keys.contains { key in
                let value = DocumentationText.value(
                    key,
                    language: language
                )
                let fragment = value.components(separatedBy: "%")[0]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return !fragment.isEmpty
                    && message.localizedCaseInsensitiveContains(fragment)
            }
        }
    }

    private static func preset(_ identifier: String) -> Self {
        UserFacingErrorPresentation(
            titleKey: "error.\(identifier).title",
            descriptionKey: "error.\(identifier).description",
            causeKey: "error.\(identifier).cause",
            solutionKey: "error.\(identifier).solution"
        )
    }
}

struct UserFacingErrorDetails: View {
    let presentation: UserFacingErrorPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Label(
                DocumentationText.value(presentation.titleKey),
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.headline)
            .foregroundStyle(Theme.Palette.error)
            .symbolRenderingMode(.hierarchical)

            Text(
                DocumentationText.value(presentation.descriptionKey)
            )
            .fixedSize(horizontal: false, vertical: true)

            detailRow(
                labelKey: "error.cause.label",
                valueKey: presentation.causeKey
            )
            detailRow(
                labelKey: "error.solution.label",
                valueKey: presentation.solutionKey
            )
        }
        .accessibilityElement(children: .combine)
    }

    private func detailRow(
        labelKey: String,
        valueKey: String
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(DocumentationText.value(labelKey))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(DocumentationText.value(valueKey))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
