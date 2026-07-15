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
                viewModel: DashboardViewModel(readers: dependencies.bookmarkReaders)
            )
        }
    }
}
