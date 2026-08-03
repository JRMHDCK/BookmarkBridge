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
        if message.localizedCaseInsensitiveContains(
            "Safari et Chrome doivent être fermés"
        ) {
            return preset("chromeRunning")
        }
        if message.localizedCaseInsensitiveContains("Deux stockages") {
            return preset("multipleStores")
        }
        if message.localizedCaseInsensitiveContains("introuvable") {
            return preset("sourceMissing")
        }
        if message.localizedCaseInsensitiveContains("Accès refusé")
            || message.localizedCaseInsensitiveContains(
                "profil Chrome en écriture"
            ) {
            return authorization
        }
        if message.localizedCaseInsensitiveContains("Format") {
            return preset("unreadable")
        }
        if message.localizedCaseInsensitiveContains("prévisualisation") {
            return preset("preview")
        }
        if message.localizedCaseInsensitiveContains("annulée") {
            return preset("cancelled")
        }
        if message.localizedCaseInsensitiveContains("Bookmarks.bak")
            || message.localizedCaseInsensitiveContains(
                "créer la sauvegarde"
            ) {
            return preset("backup")
        }
        if message.localizedCaseInsensitiveContains("restaurer") {
            return preset("restore")
        }
        if message.localizedCaseInsensitiveContains("synchronisation")
            || message.localizedCaseInsensitiveContains(
                "favoris Chrome"
            ) {
            return preset("synchronization")
        }
        if message.localizedCaseInsensitiveContains(
            "Navigateur non pris en charge"
        ) {
            return preset("unsupportedBrowser")
        }
        return preset("generic")
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
