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
        return version.map { "Version \($0)" } ?? "Application macOS"
    }
}
