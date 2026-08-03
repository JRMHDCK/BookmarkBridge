//
//  OnboardingView.swift
//  BookmarkBridge
//

import SwiftUI

struct OnboardingView: View {
    let onCompletion: () -> Void

    @State private var currentIndex = 0

    var body: some View {
        VStack(spacing: Theme.Spacing.zero) {
            onboardingPage
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack(spacing: Theme.Spacing.m) {
                stepIndicator
                Spacer()
                Button(
                    DocumentationText.value("onboarding.previous")
                ) {
                    currentIndex -= 1
                }
                .disabled(currentIndex == 0)
                .accessibilityIdentifier(
                    "documentation.onboarding.previous"
                )
                .keyboardShortcut(.leftArrow, modifiers: [])
                .help(
                    DocumentationText.value(
                        "onboarding.previous.tooltip"
                    )
                )

                Button(action: advance) {
                    Text(
                        DocumentationText.value(
                            isLastStep
                                ? "onboarding.finish"
                                : "onboarding.next"
                        )
                    )
                    .frame(minWidth: 72)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier(
                    "documentation.onboarding.primary"
                )
                .help(
                    DocumentationText.value(
                        isLastStep
                            ? "onboarding.finish.tooltip"
                            : "onboarding.next.tooltip"
                    )
                )
            }
            .padding(Theme.Spacing.l)
            .background(Theme.Materials.bar)
        }
        .frame(minWidth: 620, minHeight: 470)
        .interactiveDismissDisabled()
    }

    private var onboardingPage: some View {
        let step = OnboardingContent.steps[currentIndex]
        return VStack(spacing: Theme.Spacing.xl) {
            Group {
                switch step.icon {
                case .browser(let browser):
                    BrowserLogo(browser: browser, size: 76)
                case .system(let name):
                    Image(systemName: name)
                        .font(.system(size: 54))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.tint)
                }
            }
                .frame(width: 96, height: 96)
                .background(
                    Color.accentColor.opacity(0.10),
                    in: RoundedRectangle(
                        cornerRadius: Theme.Radius.card,
                        style: .continuous
                    )
                )
                .accessibilityLabel(
                    DocumentationText.value(step.titleKey)
                )

            VStack(spacing: Theme.Spacing.m) {
                Text(DocumentationText.value(step.titleKey))
                    .font(Theme.Typography.screenTitle)
                    .multilineTextAlignment(.center)
                Text(DocumentationText.value(step.bodyKey))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 470)
            .accessibilityElement(children: .combine)
        }
        .padding(Theme.Spacing.xxl)
        .id(step.id)
        .accessibilityIdentifier(
            "documentation.onboarding.\(step.id)"
        )
        .contentTransition(.opacity)
        .animation(Theme.Motion.stateChange, value: currentIndex)
    }

    private var stepIndicator: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(OnboardingContent.steps.indices, id: \.self) { index in
                Circle()
                    .fill(
                        index == currentIndex
                            ? Color.accentColor
                            : Color.secondary.opacity(0.25)
                    )
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            DocumentationText.formatted(
                "onboarding.progress",
                currentIndex + 1,
                OnboardingContent.steps.count
            )
        )
    }

    private var isLastStep: Bool {
        currentIndex == OnboardingContent.steps.index(
            before: OnboardingContent.steps.endIndex
        )
    }

    private func advance() {
        if isLastStep {
            onCompletion()
        } else {
            currentIndex += 1
        }
    }
}
