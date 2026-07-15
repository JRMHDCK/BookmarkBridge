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
            DashboardView(viewModel: makeDashboardViewModel())
        }
    }

    /// Builds the dashboard ViewModel, injecting the real Safari authorization
    /// flow on macOS. The coordinator (which presents NSOpenPanel) and its
    /// AppKit adapter live only here, in the app layer.
    private func makeDashboardViewModel() -> DashboardViewModel {
        #if os(macOS)
        let coordinator = SafariAccessCoordinator(
            authorizer: OpenPanelSafariAccessAuthorizer(),
            creator: dependencies.bookmarkCreator,
            store: dependencies.bookmarkStore
        )
        return DashboardViewModel(
            readers: dependencies.bookmarkReaders,
            authorizer: SafariAuthorizationRequester(coordinator: coordinator)
        )
        #else
        return DashboardViewModel(readers: dependencies.bookmarkReaders)
        #endif
    }
}
