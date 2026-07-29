//
//  AboutView.swift
//  BookmarkBridge
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Image(systemName: "bookmark")
                        .font(.largeTitle)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    Text("BookmarkBridge")
                        .font(Theme.Typography.screenTitle)
                    Text(versionDescription)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Label(
                        "Synchronisation sûre",
                        systemImage: "checkmark.shield"
                    )
                    .font(.headline)
                    .symbolRenderingMode(.hierarchical)
                    Text(
                        "BookmarkBridge prévisualise les changements et protège les données avant toute synchronisation."
                    )
                    .font(.body)
                    .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    LabeledContent("Auteur", value: "Jérôme Hudecek")
                    LabeledContent("Moteur de synchronisation", value: "BSE v1.0")
                    Text("Copyright © 2026 Jérôme Hudecek")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: 460)
            }
            .frame(
                maxWidth: Theme.Size.contentMaxWidth,
                alignment: .leading
            )
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .navigationTitle("À propos")
    }

    private var versionDescription: String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String

        guard let version else { return "Application macOS" }
        guard let build else { return "Version \(version)" }
        return "Version \(version) (Build \(build))"
    }
}
