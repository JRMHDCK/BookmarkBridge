//
//  SettingsView.swift
//  BookmarkBridge
//

import SwiftUI

/// Reserved settings destination. No preference is invented before a product
/// requirement defines its behavior and persistence.
struct SettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                SectionHeader(
                    "Réglages",
                    systemImage: "gearshape",
                    subtitle: "Les préférences de BookmarkBridge apparaîtront ici."
                )
                EmptyStateView(
                    title: "Aucun réglage disponible",
                    message: "Le comportement sûr de la synchronisation reste inchangé.",
                    systemImage: "gearshape"
                )
                .frame(minHeight: 240)
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
