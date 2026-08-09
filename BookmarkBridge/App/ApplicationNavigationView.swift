//
//  ApplicationNavigationView.swift
//  BookmarkBridge
//

import SwiftUI

/// macOS application shell. Adding a top-level screen only requires a new
/// `ApplicationScreen` case and its destination mapping.
struct ApplicationNavigationView: View {
    @Environment(DocumentationRouter.self) private var documentationRouter
    @State private var model: ApplicationViewModel
    @State private var presentsOnboarding = false
    @AppStorage(DocumentationPreferences.onboardingCompletedKey)
    private var hasCompletedOnboarding = false

    init(model: ApplicationViewModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationSplitView {
            List(ApplicationScreen.allCases, selection: screenSelection) {
                screen in
                Label(
                    DocumentationText.value(screen.titleKey),
                    systemImage: screen.systemImage
                )
                    .symbolRenderingMode(.hierarchical)
                    .tag(screen)
                    .accessibilityIdentifier(
                        "navigation.\(screen.rawValue)"
                    )
                    .accessibilityLabel(
                        DocumentationText.value(screen.titleKey)
                    )
            }
            .listStyle(.sidebar)
            .navigationTitle(DocumentationText.value("about.name"))
            .navigationSplitViewColumnWidth(
                min: Theme.Size.sidebarMinimumWidth,
                ideal: Theme.Size.sidebarIdealWidth,
                max: Theme.Size.sidebarMaximumWidth
            )
        } detail: {
            displayedDestination
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
        .alert(
            DocumentationText.value("browserClosure.title"),
            isPresented: Binding(
                get: { model.browserClosurePrompt != nil },
                set: { _ in }
            ),
            presenting: model.browserClosurePrompt
        ) { _ in
            Button(DocumentationText.value("action.cancel"), role: .cancel) {
                model.cancelBrowserClosure()
            }
            Button(DocumentationText.value("browserClosure.continue")) {
                Task { await model.closeBrowsersAndContinue() }
            }
        } message: { prompt in
            Text(browserClosureMessage(prompt.browsers))
        }
        .alert(
            DocumentationText.value("browserClosure.failure.title"),
            isPresented: Binding(
                get: { model.browserClosureError != nil },
                set: { _ in }
            )
        ) {
            Button(DocumentationText.value("action.ok")) {
                model.dismissBrowserClosureError()
            }
        } message: {
            Text(model.browserClosureError ?? "")
        }
    }

    private var screenSelection: Binding<ApplicationScreen> {
        Binding(
            get: { model.selection },
            set: { screen in
                model.selection = screen
                documentationRouter.showApplication()
            }
        )
    }

    @ViewBuilder
    private var displayedDestination: some View {
        switch documentationRouter.destination {
        case .application:
            destination(for: model.selection)
        case .helpCenter:
            HelpCenterView()
        case .whatsNew:
            WhatsNewView()
        case .about:
            AboutView()
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

    private func browserClosureMessage(_ browsers: [Browser]) -> String {
        let names = browsers.map(\.displayName).joined(separator: ", ")
        return DocumentationText.formatted(
            "browserClosure.message",
            names
        )
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
                onReload: { await model.reloadDashboard() },
                onAuthorize: { await model.authorize($0) },
                onRetry: { await model.retry($0) },
                onShowSynchronization: {
                    model.showSynchronization()
                }
            )
        case .synchronization:
            SynchronizationDirectionScreen(
                model: model.synchronization,
                isAuthorized:
                    model.authorization.state.status == .complete,
                onSelectDirection: {
                    await model.selectSynchronizationDirection($0)
                },
                onReloadDirection: {
                    await model.reload(direction: $0)
                },
                onSynchronize: { await model.synchronize() }
            )
        case .bookmarkAccess:
            BookmarkAccessView(
                model: model.bookmarkAccess,
                onLoad: { await model.loadBookmarkAccess() },
                onTestAccess: { await model.testBookmarkAccess($0) },
                onReselect: { await model.reselectBookmarkAccess($0) },
                onChangeProfile: { await model.selectChromeProfile($0) }
            )
        case .settings:
            SettingsView()
        case .about:
            AboutView()
        }
    }
}
