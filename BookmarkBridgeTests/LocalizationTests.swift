//
//  LocalizationTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("Localization")
@MainActor
struct LocalizationTests {
    @Test("Automatic selection uses the first supported macOS language")
    func automaticSelection() {
        let controller = LocalizationController(
            preferencesStore: InMemoryLocalizationPreferencesStore(),
            preferredLanguages: { ["ja-JP", "de-DE", "fr-FR"] }
        )

        #expect(controller.selectedLanguage == .automatic)
        #expect(controller.resolvedLanguage == .german)
    }

    @Test("Automatic selection falls back to English")
    func automaticFallback() {
        let controller = LocalizationController(
            preferencesStore: InMemoryLocalizationPreferencesStore(),
            preferredLanguages: { ["ja-JP", "sv-SE"] }
        )

        #expect(controller.resolvedLanguage == .english)
    }

    @Test("Manual selection is immediate and persistent")
    func manualSelectionPersists() {
        let store = InMemoryLocalizationPreferencesStore()
        let controller = LocalizationController(
            preferencesStore: store,
            preferredLanguages: { ["fr-FR"] }
        )

        controller.select(.polish)

        #expect(controller.selectedLanguage == .polish)
        #expect(controller.resolvedLanguage == .polish)
        #expect(store.language == .polish)
        let restored = LocalizationController(
            preferencesStore: store,
            preferredLanguages: { ["fr-FR"] }
        )
        #expect(restored.selectedLanguage == .polish)
    }

    @Test("Returning to Automatic follows macOS again")
    func returnsToAutomatic() {
        let store = InMemoryLocalizationPreferencesStore(language: .italian)
        let controller = LocalizationController(
            preferencesStore: store,
            preferredLanguages: { ["nl-NL"] }
        )

        controller.select(.automatic)

        #expect(controller.resolvedLanguage == .dutch)
        #expect(store.language == .automatic)
    }

    @Test("Corrupted preference is ignored")
    func corruptedPreference() throws {
        let suiteName = "LocalizationTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("unsupported-language", forKey: UserDefaultsLocalizationPreferencesStore.key)

        let store = UserDefaultsLocalizationPreferencesStore(defaults: defaults)

        #expect(store.selectedLanguage() == .automatic)
    }

    @Test("Catalog contains every key in all eight languages")
    func catalogIsComplete() throws {
        let catalogURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(
                "BookmarkBridge/Documentation/Resources/Localizable.xcstrings"
            )
        let data = try Data(contentsOf: catalogURL)
        let root = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        #expect(root["sourceLanguage"] as? String == "en")
        let strings = try #require(root["strings"] as? [String: Any])
        #expect(strings.count == 667)
        let languageCodes = Set(AppLanguage.localizedLanguages.map(\.rawValue))

        for (key, rawEntry) in strings {
            let entry = try #require(rawEntry as? [String: Any])
            let localizations = try #require(
                entry["localizations"] as? [String: Any]
            )
            #expect(Set(localizations.keys) == languageCodes, "Missing language for \(key)")
            for language in languageCodes {
                let localization = try #require(
                    localizations[language] as? [String: Any]
                )
                let unit = try #require(
                    localization["stringUnit"] as? [String: Any]
                )
                let value = try #require(unit["value"] as? String)
                #expect(!value.isEmpty, "Empty \(language) translation for \(key)")
            }
        }
    }

    @Test("Each manual language name resolves independently")
    func languagesResolve() {
        let expected: [AppLanguage: String] = [
            .english: "Settings",
            .french: "Paramètres",
            .spanish: "Configuración",
            .german: "Einstellungen",
            .italian: "Impostazioni",
            .portuguese: "Configurações",
            .dutch: "Instellingen",
            .polish: "Ustawienia",
        ]

        for (language, title) in expected {
            #expect(
                DocumentationText.value(
                    "settings.title",
                    language: language
                ) == title
            )
        }
    }
}
