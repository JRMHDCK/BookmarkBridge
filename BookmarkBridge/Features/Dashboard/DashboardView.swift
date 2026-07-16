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
    @State private var searchModel: SearchViewModel
    @State private var syncModel: SyncPreviewViewModel
    @State private var showingSyncPreview = false
    @State private var path: [ExplorerStep] = []

    init(
        viewModel: DashboardViewModel,
        searchEngine: any BookmarkSearching = BookmarkSearchEngine(),
        chromeApplier: (any ChromeBookmarkApplying)? = nil,
        backup: (any BookmarkBackup)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        _searchModel = State(initialValue: SearchViewModel(engine: searchEngine))
        _syncModel = State(initialValue: SyncPreviewViewModel(applier: chromeApplier, backup: backup))
    }

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationDestination(for: ExplorerStep.self) { step in
                    explorerDestination(for: step, path: $path)
                }
                .navigationTitle("BookmarkBridge")
                .toolbar {
                    ToolbarItem {
                        Button {
                            presentSyncPreview()
                        } label: {
                            Label("Synchroniser…", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .disabled(syncPair == nil)
                        .accessibilityLabel("Prévisualiser la synchronisation")
                    }
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
                .searchable(text: $searchModel.query, prompt: "Rechercher un favori")
                .onChange(of: viewModel.searchableSources, initial: true) { _, sources in
                    searchModel.updateSources(sources)
                }
                .sheet(isPresented: $showingSyncPreview) {
                    NavigationStack {
                        SyncPreviewView(model: syncModel)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Annuler") { showingSyncPreview = false }
                                }
                            }
                    }
                    .frame(minWidth: 480, minHeight: 440)
                }
        }
        .frame(minWidth: 420, minHeight: 300)
        .task { await viewModel.load() }
    }

    /// The Safari + first Chrome loaded sources, when both are available. Pair
    /// selection is deliberately simple for now (UX refinement comes later).
    private var syncPair: (SearchableSource, SearchableSource)? {
        let sources = viewModel.searchableSources
        guard let safari = sources.first(where: { $0.source.browser == .safari }),
              let chrome = sources.first(where: { $0.source.browser == .chrome }) else {
            return nil
        }
        return (safari, chrome)
    }

    private func presentSyncPreview() {
        let sources = viewModel.searchableSources
        guard let safari = sources.first(where: { $0.source.browser == .safari }) else { return }
        let chromeCandidates = sources
            .filter { $0.source.browser == .chrome }
            .map { candidate in
                SyncPreviewViewModel.ChromeCandidate(
                    source: candidate.source,
                    tree: candidate.tree,
                    writable: viewModel.writableLocation(for: candidate.source.id),
                    scope: viewModel.writableScopeDirectory(for: candidate.source.id)
                )
            }
        guard !chromeCandidates.isEmpty else { return }
        syncModel.configure(safari: (safari.source, safari.tree), chromeCandidates: chromeCandidates)
        showingSyncPreview = true
    }

    /// Search results replace the dashboard while a query is active; an empty
    /// query shows the unchanged dashboard (no regression).
    @ViewBuilder
    private var content: some View {
        if searchModel.hasQuery {
            SearchResultsView(model: searchModel, onSelect: openResult)
        } else {
            dashboard
        }
    }

    /// Reveals a search hit by driving the existing explorer navigation: resolve
    /// the hit to an `[ExplorerStep]` chain and set the shared path. The query
    /// stays active, so the back button returns to the results. Read-only.
    private func openResult(_ result: BookmarkSearchResult) {
        guard let tree = viewModel.tree(for: result.source.id) else { return }
        path = ExplorerStep.path(to: result, in: tree)
    }

    private var dashboard: some View {
        ScrollView {
            if viewModel.sources.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, minHeight: 240)
            } else {
                VStack(spacing: Theme.Spacing.l) {
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
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            header
            Divider()
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Theme.Spacing.m) {
            browserIcon
            Text(entry.source.displayName)
                .font(Theme.Typography.cardTitle)
            Spacer()
            if case .loaded = entry.status {
                ReadOnlyBadge()
            }
        }
    }

    /// A small rounded, blue-tinted tile carrying the browser glyph — reinforces
    /// the brand identity while identifying the source at a glance.
    private var browserIcon: some View {
        Image(systemName: symbolName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.Palette.blue)
            .frame(width: 30, height: 30)
            .background(
                Theme.Palette.blueSubtle,
                in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
            )
            .accessibilityHidden(true)
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
        HStack(spacing: Theme.Spacing.s) {
            ProgressView().controlSize(.small)
            Text("Lecture des favoris…").foregroundStyle(.secondary)
        }
        .accessibilityLabel("Lecture des favoris en cours")
    }

    private func loadedState(_ summary: BrowserBookmarkSummary) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(alignment: .top, spacing: Theme.Spacing.s) {
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
                        .font(.callout.weight(.medium))
                }
                .accessibilityLabel("Explorer les favoris de \(entry.source.displayName)")
            }
        }
    }

    /// One statistic as a subtle tile, so the figures read as a group and the
    /// rounded, brand-blue numbers reinforce the identity.
    private func stat(value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(value, format: .number)
                .font(Theme.Typography.statNumber)
                .foregroundStyle(Theme.Palette.blue)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.Spacing.s)
        .padding(.horizontal, Theme.Spacing.m)
        .background(Theme.Palette.blueSubtle.opacity(0.5), in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) : \(value)")
    }

    private var authorizationRequiredState: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Label(
                "BookmarkBridge a besoin d'un accès en lecture seule au fichier des favoris.",
                systemImage: "lock"
            )
            .foregroundStyle(.secondary)
            Button("Autoriser l'accès…", action: onAuthorize)
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Autoriser l'accès aux favoris \(entry.source.displayName)")
        }
    }

    private func failedState(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Label {
                Text(message).foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.Palette.error)
            }
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
