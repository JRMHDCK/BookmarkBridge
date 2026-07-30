//
//  ApplicationNavigationView.swift
//  BookmarkBridge
//

import SwiftUI

/// macOS application shell. Adding a top-level screen only requires a new
/// `ApplicationScreen` case and its destination mapping.
struct ApplicationNavigationView: View {
    @State private var model: ApplicationViewModel
    @State private var presentsOnboarding = false
    @AppStorage(DocumentationPreferences.onboardingCompletedKey)
    private var hasCompletedOnboarding = false

    init(model: ApplicationViewModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            List(ApplicationScreen.allCases, selection: $model.selection) {
                screen in
                Label(screen.title, systemImage: screen.systemImage)
                    .symbolRenderingMode(.hierarchical)
                    .tag(screen)
                    .accessibilityLabel(screen.title)
            }
            .listStyle(.sidebar)
            .navigationTitle("BookmarkBridge")
            .navigationSplitViewColumnWidth(
                min: Theme.Size.sidebarMinimumWidth,
                ideal: Theme.Size.sidebarIdealWidth,
                max: Theme.Size.sidebarMaximumWidth
            )
        } detail: {
            destination(for: model.selection)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(
            minWidth: Theme.Size.windowMinimumWidth,
            minHeight: Theme.Size.windowMinimumHeight
        )
        .task {
            await model.loadIfNeeded()
        }
        .onAppear {
            if skipsOnboardingForUITests {
                presentsOnboarding = false
            } else {
                presentsOnboarding =
                    forcesOnboardingForUITests
                    || !hasCompletedOnboarding
            }
        }
        .onChange(of: hasCompletedOnboarding) { _, isCompleted in
            if !isCompleted {
                presentsOnboarding = true
            }
        }
        .sheet(isPresented: $presentsOnboarding) {
            OnboardingView {
                hasCompletedOnboarding = true
                presentsOnboarding = false
            }
        }
    }

    private var forcesOnboardingForUITests: Bool {
        ProcessInfo.processInfo.environment[
            DocumentationPreferences.onboardingUITestEnvironmentKey
        ] == "1"
    }

    private var skipsOnboardingForUITests: Bool {
        ProcessInfo.processInfo.environment[
            DocumentationPreferences.onboardingUITestSkipEnvironmentKey
        ] == "1"
    }

    @ViewBuilder
    private func destination(for screen: ApplicationScreen) -> some View {
        switch screen {
        case .dashboard:
            DashboardView(
                viewModel: model.dashboard,
                authorizationViewModel: model.authorization,
                synchronizationSummary:
                    model.dashboardSynchronizationSummary,
                loadsOnAppear: false,
                onReload: { await model.reload() },
                onAuthorize: { await model.authorize($0) },
                onRetry: { await model.retry($0) },
                onShowSynchronization: {
                    model.showSynchronization()
                }
            )
        case .synchronization:
            SynchronizationPreviewScreen(
                model: model.synchronization,
                isAuthorized:
                    model.authorization.state.status == .complete,
                onReload: { await model.reload() },
                onSynchronize: { await model.synchronize() }
            )
        case .settings:
            SettingsView()
        case .about:
            AboutView()
        }
    }
}
