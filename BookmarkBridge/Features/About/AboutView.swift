//
//  AboutView.swift
//  BookmarkBridge
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                SectionHeader(
                    "BookmarkBridge",
                    systemImage: "bookmark.fill",
                    subtitle: versionDescription
                )
                StatusCard(
                    "Synchronisation sûre",
                    systemImage: "checkmark.shield"
                ) {
                    Text(
                        "BookmarkBridge prévisualise les changements et protège les données avant toute synchronisation."
                    )
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
