//
//  ApplicationNavigationView.swift
//  BookmarkBridge
//

import SwiftUI

/// macOS application shell. Adding a top-level screen only requires a new
/// `ApplicationScreen` case and its destination mapping.
struct ApplicationNavigationView: View {
    @State private var model: ApplicationViewModel

    init(model: ApplicationViewModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            List(ApplicationScreen.allCases, selection: $model.selection) {
                screen in
                Label(screen.title, systemImage: screen.systemImage)
                    .tag(screen)
                    .accessibilityLabel(screen.title)
            }
            .navigationTitle("BookmarkBridge")
            .navigationSplitViewColumnWidth(
                ideal: Theme.Size.sidebarIdealWidth
            )
        } detail: {
            destination(for: model.selection)
        }
        .frame(minWidth: 680, minHeight: 460)
        .task {
            await model.loadIfNeeded()
        }
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
