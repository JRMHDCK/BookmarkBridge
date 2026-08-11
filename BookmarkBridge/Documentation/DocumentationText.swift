//
//  DocumentationText.swift
//  BookmarkBridge
//

import Foundation

enum DocumentationText {
    static func value(_ key: String) -> String {
        value(key, language: resolvedLanguage())
    }

    static func value(_ key: String, language: AppLanguage) -> String {
        localizedBundle(for: language).localizedString(
            forKey: key,
            value: key,
            table: "Localizable"
        )
    }

    static func formatted(_ key: String, _ arguments: CVarArg...) -> String {
        String(
            format: value(key),
            locale: Locale(identifier: resolvedLanguage().rawValue),
            arguments: arguments
        )
    }

    static func formatted(
        _ key: String,
        language: AppLanguage,
        _ arguments: CVarArg...
    ) -> String {
        String(
            format: value(key, language: language),
            locale: Locale(identifier: language.rawValue),
            arguments: arguments
        )
    }

    static func resolvedLanguage(
        defaults: UserDefaults = .standard,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> AppLanguage {
        let selection = AppLanguage(
            rawValue: defaults.string(
                forKey: UserDefaultsLocalizationPreferencesStore.key
            ) ?? ""
        ) ?? .automatic
        return LocalizationController.resolve(
            selection,
            preferredLanguages: preferredLanguages
        )
    }

    static func localizedBundle(for language: AppLanguage) -> Bundle {
        guard language != .automatic,
              let path = Bundle.main.path(
                  forResource: language.rawValue,
                  ofType: "lproj"
              ),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}

enum DocumentationPreferences {
    static let onboardingCompletedKey =
        "documentation.onboarding.hasCompleted"
    static let onboardingUITestEnvironmentKey =
        "BOOKMARKBRIDGE_UI_TEST_ONBOARDING"
    static let onboardingUITestSkipEnvironmentKey =
        "BOOKMARKBRIDGE_UI_TEST_SKIP_ONBOARDING"
    static let helpCenterUITestEnvironmentKey =
        "BOOKMARKBRIDGE_UI_TEST_HELP_CENTER"
    static let helpAfterBugReportUITestEnvironmentKey =
        "BOOKMARKBRIDGE_UI_TEST_HELP_AFTER_BUG_REPORT"
}
