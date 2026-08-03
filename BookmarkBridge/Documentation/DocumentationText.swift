//
//  DocumentationText.swift
//  BookmarkBridge
//

import Foundation

enum DocumentationText {
    static func value(_ key: String) -> String {
        Bundle.main.localizedString(
            forKey: key,
            value: key,
            table: "Localizable"
        )
    }

    static func formatted(_ key: String, _ arguments: CVarArg...) -> String {
        String(
            format: value(key),
            locale: Locale.current,
            arguments: arguments
        )
    }
}

enum DocumentationPreferences {
    static let onboardingCompletedKey =
        "documentation.onboarding.hasCompleted"
    static let onboardingUITestEnvironmentKey =
        "BOOKMARKBRIDGE_UI_TEST_ONBOARDING"
    static let onboardingUITestSkipEnvironmentKey =
        "BOOKMARKBRIDGE_UI_TEST_SKIP_ONBOARDING"
}
