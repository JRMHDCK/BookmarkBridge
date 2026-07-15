//
//  DashboardView.swift
//  BookmarkBridge
//
//  Created by Jerome on 15/07/2026.
//

import SwiftUI

/// Read-only overview of the bookmarks found in each browser.
///
/// Presentation only: it renders per-browser state from `DashboardViewModel` and
/// forwards the initial load and authorization intents. No business logic or I/O
/// lives here. (Minimal rendering for now; the polished UI is a later step.)
struct DashboardView: View {
    @State private var viewModel: DashboardViewModel

    init(viewModel: DashboardViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List(viewModel.browsers) { entry in
            row(for: entry)
        }
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private func row(for entry: DashboardViewModel.BrowserState) -> some View {
        HStack {
            Text(entry.browser.displayName)
            Spacer()
            switch entry.status {
            case .loading:
                ProgressView()
            case .loaded(let summary):
                Text("\(summary.bookmarkCount) favoris")
                    .foregroundStyle(.secondary)
            case .authorizationRequired:
                Button("Autoriser l'accès") {
                    Task { await viewModel.authorize(entry.browser) }
                }
            case .failed(let message):
                Text(message)
                    .foregroundStyle(.red)
                    .lineLimit(1)
                    .help(message)
            }
        }
    }
}

#Preview {
    DashboardView(
        viewModel: DashboardViewModel(readers: [
            InMemoryBookmarkReader(browser: .safari, tree: .sample(for: .safari))
        ])
    )
}
