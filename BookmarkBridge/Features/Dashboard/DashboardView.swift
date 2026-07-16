//
//  DashboardView.swift
//  BookmarkBridge
//
//  Created by Jerome on 15/07/2026.
//

import SwiftUI

/// Read-only overview of the bookmarks found in each source (browser/profile).
///
/// Presentation only: it renders per-source state from `DashboardViewModel` and
/// forwards load / reload / authorize / retry intents. It performs no I/O and
/// never walks a `BookmarkTree` — it reads the already-computed summary fields.
struct DashboardView: View {
    @State private var viewModel: DashboardViewModel
    @State private var path: [ExplorerStep] = []

    init(viewModel: DashboardViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                if viewModel.sources.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity, minHeight: 240)
                } else {
                    VStack(spacing: 16) {
                        ForEach(viewModel.sources) { entry in
                            SourceCard(
                                entry: entry,
                                tree: viewModel.tree(for: entry.id),
                                onAuthorize: { Task { await viewModel.authorize(entry.source.id) } },
                                onRetry: { Task { await viewModel.retry(entry.source.id) } }
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationDestination(for: ExplorerStep.self) { step in
                explorerDestination(for: step)
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

/// A single source's card, rendering one of the four states.
private struct SourceCard: View {
    let entry: DashboardViewModel.SourceState
    /// The decoded tree for this source, when loaded — enables the explorer link.
    let tree: BookmarkTree?
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
            Text(entry.source.displayName)
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
            if let tree {
                NavigationLink(value: ExplorerStep.source(entry.source, tree)) {
                    Label("Explorer les favoris", systemImage: "chevron.forward")
                        .font(.callout)
                }
                .accessibilityLabel("Explorer les favoris de \(entry.source.displayName)")
            }
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
                .accessibilityLabel("Autoriser l'accès aux favoris \(entry.source.displayName)")
        }
    }

    private func failedState(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
            Button("Réessayer", action: onRetry)
                .accessibilityLabel("Réessayer la lecture des favoris \(entry.source.displayName)")
        }
    }

    // MARK: - Browser icon (extensible per browser)

    private var symbolName: String {
        switch entry.source.browser {
        case .safari: "safari"
        case .chrome: "globe"
        }
    }
}

// MARK: - Previews

private extension DashboardViewModel.SourceState {
    static func preview(_ status: DashboardViewModel.Status) -> Self {
        .init(source: .singleProfile(.safari), status: status)
    }
}

#Preview("Chargé") {
    NavigationStack {
        SourceCard(
            entry: .preview(.loaded(BrowserBookmarkSummary(tree: .sample(for: .safari)))),
            tree: .sample(for: .safari),
            onAuthorize: {},
            onRetry: {}
        )
        .padding()
        .frame(width: 460)
    }
}

#Preview("Autorisation requise") {
    SourceCard(entry: .preview(.authorizationRequired), tree: nil, onAuthorize: {}, onRetry: {})
        .padding()
        .frame(width: 460)
}

#Preview("Erreur") {
    SourceCard(entry: .preview(.failed("Format du fichier illisible.")), tree: nil, onAuthorize: {}, onRetry: {})
        .padding()
        .frame(width: 460)
}

#Preview("Chargement") {
    SourceCard(entry: .preview(.loading), tree: nil, onAuthorize: {}, onRetry: {})
        .padding()
        .frame(width: 460)
}

#Preview("Dashboard (in-memory)") {
    DashboardView(
        viewModel: DashboardViewModel(providers: [
            SafariSourceProvider(reader: InMemoryBookmarkReader(browser: .safari, tree: .sample(for: .safari)))
        ])
    )
}
