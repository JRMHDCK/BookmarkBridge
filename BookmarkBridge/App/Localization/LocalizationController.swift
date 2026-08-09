//
//  LocalizationController.swift
//  BookmarkBridge
//

import Foundation
import Observation

nonisolated enum AppLanguage: String, CaseIterable, Codable, Sendable {
    case automatic
    case french = "fr"
    case english = "en"
    case spanish = "es"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case dutch = "nl"
    case polish = "pl"

    static let localizedLanguages: [AppLanguage] = [
        .french,
        .english,
        .spanish,
        .german,
        .italian,
        .portuguese,
        .dutch,
        .polish,
    ]

    nonisolated var localizationKey: String {
        "settings.language.\(rawValue)"
    }
}

@MainActor
protocol LocalizationPreferencesStoring: Sendable {
    func selectedLanguage() -> AppLanguage
    func saveSelectedLanguage(_ language: AppLanguage)
}

@MainActor
struct UserDefaultsLocalizationPreferencesStore:
    LocalizationPreferencesStoring
{
    static let key = "Localization.SelectedLanguage"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func selectedLanguage() -> AppLanguage {
        guard let rawValue = defaults.string(forKey: Self.key),
              let language = AppLanguage(rawValue: rawValue) else {
            return .automatic
        }
        return language
    }

    func saveSelectedLanguage(_ language: AppLanguage) {
        defaults.set(language.rawValue, forKey: Self.key)
    }
}

@MainActor
@Observable
final class LocalizationController {
    private(set) var selectedLanguage: AppLanguage
    private let preferencesStore: any LocalizationPreferencesStoring
    private let preferredLanguages: () -> [String]

    init(
        preferencesStore: any LocalizationPreferencesStoring =
            UserDefaultsLocalizationPreferencesStore(),
        preferredLanguages: @escaping () -> [String] = {
            Locale.preferredLanguages
        }
    ) {
        self.preferencesStore = preferencesStore
        self.preferredLanguages = preferredLanguages
        selectedLanguage = preferencesStore.selectedLanguage()
    }

    var resolvedLanguage: AppLanguage {
        Self.resolve(
            selectedLanguage,
            preferredLanguages: preferredLanguages()
        )
    }

    var locale: Locale {
        Locale(identifier: resolvedLanguage.rawValue)
    }

    func select(_ language: AppLanguage) {
        guard selectedLanguage != language else { return }
        selectedLanguage = language
        preferencesStore.saveSelectedLanguage(language)
    }

    nonisolated static func resolve(
        _ selection: AppLanguage,
        preferredLanguages: [String]
    ) -> AppLanguage {
        guard selection == .automatic else { return selection }
        for identifier in preferredLanguages {
            let languageCode = Locale(identifier: identifier)
                .language.languageCode?.identifier
            if let language = AppLanguage.localizedLanguages.first(
                where: { $0.rawValue == languageCode }
            ) {
                return language
            }
        }
        return .english
    }
}

@MainActor
final class InMemoryLocalizationPreferencesStore:
    LocalizationPreferencesStoring
{
    private(set) var language: AppLanguage

    init(language: AppLanguage = .automatic) {
        self.language = language
    }

    func selectedLanguage() -> AppLanguage { language }

    func saveSelectedLanguage(_ language: AppLanguage) {
        self.language = language
    }
}
