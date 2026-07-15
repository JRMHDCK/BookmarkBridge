//
//  DashboardView.swift
//  BookmarkBridge
//
//  Created by Jerome on 15/07/2026.
//

import SwiftUI

/// Read-only overview of the bookmarks found in each browser.
///
/// Presentation only: it renders `DashboardViewModel.state` and forwards the
/// initial load. No business logic or I/O lives here.
struct DashboardView: View {
    @State private var viewModel: DashboardViewModel

    init(viewModel: DashboardViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        content
            .padding()
            .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView("Lecture des favoris…")
        case .loaded(let summaries):
            List(summaries) { summary in
                HStack {
                    Text(summary.browser.displayName)
                    Spacer()
                    Text("\(summary.bookmarkCount) favoris")
                        .foregroundStyle(.secondary)
                }
            }
        case .failed(let message):
            ContentUnavailableView(
                "Lecture impossible",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
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
