//
//  SettingsView.swift
//  BookmarkBridge
//

import SwiftUI

/// Explains the absence of configurable preferences without implying that the
/// application is incomplete.
struct SettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                ScreenHeader(
                    "Réglages",
                    subtitle:
                        "BookmarkBridge privilégie des réglages sûrs et prévisibles."
                )
                EmptyStateView(
                    title: "Aucun réglage nécessaire",
                    message: "La synchronisation utilise automatiquement les options recommandées.",
                    systemImage: "checkmark.circle"
                )
                .frame(
                    minHeight:
                        Theme.Size.emptyStateMinimumHeight
                )
            }
            .frame(
                maxWidth: Theme.Size.contentMaxWidth,
                alignment: .leading
            )
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .navigationTitle("Réglages")
    }
}
