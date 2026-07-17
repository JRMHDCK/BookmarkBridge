//
//  BookmarkBridgeApp.swift
//  BookmarkBridge
//
//  Created by Jerome on 15/07/2026.
//

import SwiftUI

@main
struct BookmarkBridgeApp: App {
    /// Assembled once at launch and injected into the feature ViewModels.
    private let dependencies = AppDependencies.bootstrap()

    var body: some Scene {
        WindowGroup {
            DashboardView(
                viewModel: makeDashboardViewModel(),
                chromeApplier: ChromeBookmarkApplier(
                    detector: SystemRunningBrowserDetector(),
                    backup: dependencies.backup
                ),
                backup: dependencies.backup,
                browserDetector: SystemRunningBrowserDetector()
            )
        }
    }

    /// Builds the dashboard ViewModel, injecting the real per-browser
    /// authorization flows on macOS. The coordinators (which present NSOpenPanel)
    /// and their AppKit adapters live only here, in the app layer.
    private func makeDashboardViewModel() -> DashboardViewModel {
        #if os(macOS)
        let safariCoordinator = BrowserAccessCoordinator(
            browser: .safari,
            expectedPathSuffix: BrowserAccessCoordinator.safariPathSuffix,
            authorizer: OpenPanelFileAuthorizer(),
            creator: dependencies.bookmarkCreator,
            store: dependencies.bookmarkStore
        )
        let chromeCoordinator = BrowserAccessCoordinator(
            browser: .chrome,
            expectedPathSuffix: BrowserAccessCoordinator.chromeDirectorySuffix,
            authorizer: OpenPanelDirectoryAuthorizer(),
            creator: dependencies.bookmarkCreator,
            store: dependencies.bookmarkStore
        )
        let requester = CompositeAuthorizationRequester([
            .safari: BrowserAuthorizationRequester(browser: .safari, coordinator: safariCoordinator),
            .chrome: BrowserAuthorizationRequester(browser: .chrome, coordinator: chromeCoordinator),
        ])
        return DashboardViewModel(providers: dependencies.providers, authorizer: requester)
        #else
        return DashboardViewModel(providers: dependencies.providers)
        #endif
    }
}
