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
            icon: .system("hand.wave")
        ),
        OnboardingStep(
            id: "overview",
            titleKey: "onboarding.overview.title",
            bodyKey: "onboarding.overview.body",
            icon: .system("bookmark.square")
        ),
        OnboardingStep(
            id: "workflow",
            titleKey: "onboarding.workflow.title",
            bodyKey: "onboarding.workflow.body",
            icon: .system("arrow.triangle.2.circlepath")
        ),
        OnboardingStep(
            id: "privacy",
            titleKey: "onboarding.privacy.title",
            bodyKey: "onboarding.privacy.body",
            icon: .system("hand.raised")
        ),
        OnboardingStep(
            id: "safari",
            titleKey: "onboarding.safari.title",
            bodyKey: "onboarding.safari.body",
            icon: .browser(.safari)
        ),
        OnboardingStep(
            id: "chrome",
            titleKey: "onboarding.chrome.title",
            bodyKey: "onboarding.chrome.body",
            icon: .browser(.chrome)
        ),
        OnboardingStep(
            id: "firstSync",
            titleKey: "onboarding.firstSync.title",
            bodyKey: "onboarding.firstSync.body",
            icon: .system("checkmark.shield")
        ),
        OnboardingStep(
            id: "finish",
            titleKey: "onboarding.finish.title",
            bodyKey: "onboarding.finish.body",
            icon: .system("checkmark.circle")
        ),
    ]
}
