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
            rootView
        }
    }

    @ViewBuilder
    private var rootView: some View {
        #if os(macOS)
        // Temporary diagnostic entry for the manual real-access validation
        // (see App/Diagnostics). Not the definitive wiring.
        if CommandLine.arguments.contains("--validate-safari-access") {
            SafariAccessValidationView()
        } else {
            dashboard
        }
        #else
        dashboard
        #endif
    }

    private var dashboard: some View {
        DashboardView(
            viewModel: DashboardViewModel(readers: dependencies.bookmarkReaders)
        )
    }
}
