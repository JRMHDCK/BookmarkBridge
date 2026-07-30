//
//  OnboardingContent.swift
//  BookmarkBridge
//

enum OnboardingContent {
    static let steps: [OnboardingStep] = [
        OnboardingStep(
            id: "welcome",
            titleKey: "onboarding.welcome.title",
            bodyKey: "onboarding.welcome.body",
            systemImage: "hand.wave"
        ),
        OnboardingStep(
            id: "overview",
            titleKey: "onboarding.overview.title",
            bodyKey: "onboarding.overview.body",
            systemImage: "bookmark.square"
        ),
        OnboardingStep(
            id: "workflow",
            titleKey: "onboarding.workflow.title",
            bodyKey: "onboarding.workflow.body",
            systemImage: "arrow.triangle.2.circlepath"
        ),
        OnboardingStep(
            id: "privacy",
            titleKey: "onboarding.privacy.title",
            bodyKey: "onboarding.privacy.body",
            systemImage: "hand.raised"
        ),
        OnboardingStep(
            id: "safari",
            titleKey: "onboarding.safari.title",
            bodyKey: "onboarding.safari.body",
            systemImage: "safari"
        ),
        OnboardingStep(
            id: "chrome",
            titleKey: "onboarding.chrome.title",
            bodyKey: "onboarding.chrome.body",
            systemImage: "globe"
        ),
        OnboardingStep(
            id: "firstSync",
            titleKey: "onboarding.firstSync.title",
            bodyKey: "onboarding.firstSync.body",
            systemImage: "checkmark.shield"
        ),
        OnboardingStep(
            id: "finish",
            titleKey: "onboarding.finish.title",
            bodyKey: "onboarding.finish.body",
            systemImage: "checkmark.circle"
        ),
    ]
}
