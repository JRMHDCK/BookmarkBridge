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
/// forwards load / reload / authorize / retry intents. It performs no I/O and
/// never walks a `BookmarkTree` — it reads the already-computed summary fields.
struct DashboardView: View {
    @State private var viewModel: DashboardViewModel

    init(viewModel: DashboardViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.browsers.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity, minHeight: 240)
                } else {
                    VStack(spacing: 16) {
                        ForEach(viewModel.browsers) { entry in
                            BrowserCard(
                                entry: entry,
                                onAuthorize: { Task { await viewModel.authorize(entry.browser) } },
                                onRetry: { Task { await viewModel.retry(entry.browser) } }
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("BookmarkBridge")
            .toolbar {
                ToolbarItem {
                    Button {
                        Task { await viewModel.reloadAll() }
                    } label: {
                        Label("Actualiser", systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                    .accessibilityLabel("Actualiser tous les navigateurs")
                }
            }
        }
        .frame(minWidth: 420, minHeight: 300)
        .task { await viewModel.load() }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Aucun navigateur configuré",
            systemImage: "bookmark.slash",
            description: Text("Aucune source de favoris n'est disponible.")
        )
    }
}

/// A single browser's card, rendering one of the four states.
private struct BrowserCard: View {
    let entry: DashboardViewModel.BrowserState
    let onAuthorize: () -> Void
    let onRetry: () -> Void

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                header
                Divider()
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: symbolName)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(entry.browser.displayName)
                .font(.headline)
            Spacer()
            if case .loaded = entry.status {
                readOnlyBadge
            }
        }
    }

    private var readOnlyBadge: some View {
        Label("Lecture seule", systemImage: "lock.fill")
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.quaternary, in: Capsule())
            .accessibilityLabel("Accès en lecture seule")
    }

    // MARK: - Content per state

    @ViewBuilder
    private var content: some View {
        switch entry.status {
        case .loading:
            loadingState
        case .loaded(let summary):
            loadedState(summary)
        case .authorizationRequired:
            authorizationRequiredState
        case .failed(let message):
            failedState(message)
        }
    }

    private var loadingState: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text("Lecture des favoris…").foregroundStyle(.secondary)
        }
        .accessibilityLabel("Lecture des favoris en cours")
    }

    private func loadedState(_ summary: BrowserBookmarkSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 28) {
                stat(value: summary.folderCount, label: "Dossiers")
                stat(value: summary.bookmarkCount, label: "Favoris")
                stat(value: summary.nodeCount, label: "Nœuds")
            }
            Text("Lu le \(summary.capturedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel(
                    "Dernière lecture le \(summary.capturedAt.formatted(date: .long, time: .standard))"
                )
        }
    }

    private func stat(value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value, format: .number)
                .font(.title3)
                .monospacedDigit()
                .fontWeight(.semibold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) : \(value)")
    }

    private var authorizationRequiredState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(
                "BookmarkBridge a besoin d'un accès en lecture seule au fichier des favoris.",
                systemImage: "lock"
            )
            .foregroundStyle(.secondary)
            Button("Autoriser l'accès…", action: onAuthorize)
                .accessibilityLabel("Autoriser l'accès aux favoris \(entry.browser.displayName)")
        }
    }

    private func failedState(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
            Button("Réessayer", action: onRetry)
                .accessibilityLabel("Réessayer la lecture des favoris \(entry.browser.displayName)")
        }
    }

    // MARK: - Browser icon (extensible per browser)

    private var symbolName: String {
        switch entry.browser {
        case .safari: "safari"
        case .chrome: "globe"
        }
    }
}

// MARK: - Previews

#Preview("Chargé") {
    BrowserCard(
        entry: .init(browser: .safari, status: .loaded(BrowserBookmarkSummary(tree: .sample(for: .safari)))),
        onAuthorize: {},
        onRetry: {}
    )
    .padding()
    .frame(width: 460)
}

#Preview("Autorisation requise") {
    BrowserCard(
        entry: .init(browser: .safari, status: .authorizationRequired),
        onAuthorize: {},
        onRetry: {}
    )
    .padding()
    .frame(width: 460)
}

#Preview("Erreur") {
    BrowserCard(
        entry: .init(browser: .safari, status: .failed("Format du fichier illisible.")),
        onAuthorize: {},
        onRetry: {}
    )
    .padding()
    .frame(width: 460)
}

#Preview("Chargement") {
    BrowserCard(
        entry: .init(browser: .safari, status: .loading),
        onAuthorize: {},
        onRetry: {}
    )
    .padding()
    .frame(width: 460)
}

#Preview("Dashboard (in-memory)") {
    DashboardView(
        viewModel: DashboardViewModel(readers: [
            InMemoryBookmarkReader(browser: .safari, tree: .sample(for: .safari))
        ])
    )
}
