//
//  SettingsView.swift
//  BookmarkBridge
//

import SwiftUI

/// Explains the absence of configurable preferences without implying that the
/// application is incomplete.
struct SettingsView: View {
    @Environment(LocalizationController.self) private var localization
    @AppStorage(DocumentationPreferences.onboardingCompletedKey)
    private var hasCompletedOnboarding = false

    var body: some View {
        @Bindable var localization = localization
        return ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                ScreenHeader(
                    DocumentationText.value("settings.title"),
                    subtitle: DocumentationText.value("settings.subtitle")
                )

                SectionHeader(
                    DocumentationText.value("settings.language.title"),
                    systemImage: "globe",
                    subtitle: DocumentationText.value(
                        "settings.language.subtitle"
                    )
                )

                Picker(
                    DocumentationText.value("settings.language.picker"),
                    selection: Binding(
                        get: { localization.selectedLanguage },
                        set: { localization.select($0) }
                    )
                ) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(DocumentationText.value(language.localizationKey))
                            .tag(language)
                            .accessibilityIdentifier(
                                "settings.language.option.\(language.rawValue)"
                            )
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("settings.language.picker")
                .accessibilityHint(
                    DocumentationText.value("settings.language.hint")
                )

                SectionHeader(
                    DocumentationText.value(
                        "settings.guidance.title"
                    ),
                    systemImage: "graduationcap",
                    subtitle: DocumentationText.value(
                        "settings.guidance.subtitle"
                    )
                )

                SecondaryActionButton(
                    DocumentationText.value(
                        "settings.guidance.replay"
                    ),
                    systemImage: "arrow.counterclockwise"
                ) {
                    hasCompletedOnboarding = false
                }
                .help(
                    DocumentationText.value(
                        "settings.guidance.replay.tooltip"
                    )
                )
            }
            .frame(
                maxWidth: Theme.Size.contentMaxWidth,
                alignment: .leading
            )
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .navigationTitle(DocumentationText.value("settings.title"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ContextualHelpButton(pageID: .configuration)
            }
        }
    }
}
