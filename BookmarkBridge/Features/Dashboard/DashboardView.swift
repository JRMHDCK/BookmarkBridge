//
//  DashboardView.swift
//  BookmarkBridge
//

import SwiftUI

nonisolated enum DashboardSynchronizationSummary: Equatable, Sendable {
    case idle
    case loading
    case changes(Int)
    case upToDate
    case failed(String)
}

/// Home screen: source health, permissions and synchronization overview.
/// Detailed preview and execution live in the Synchronisation feature.
struct DashboardView: View {
    @State private var viewModel: DashboardViewModel
    @State private var authorizationViewModel:
        ApplicationAuthorizationViewModel?
    @State private var searchModel: SearchViewModel
    @State private var path: [ExplorerStep] = []

    let synchronizationSummary: DashboardSynchronizationSummary
    let loadsOnAppear: Bool
    let onReload: (@MainActor () async -> Void)?
    let onAuthorize: (@MainActor (Browser) async -> Void)?
    let onRetry: (@MainActor (BookmarkSourceID) async -> Void)?
    let onShowSynchronization: (() -> Void)?

    init(
        viewModel: DashboardViewModel,
        authorizationViewModel: ApplicationAuthorizationViewModel? = nil,
        synchronizationSummary: DashboardSynchronizationSummary = .idle,
        searchEngine: any BookmarkSearching = BookmarkSearchEngine(),
        loadsOnAppear: Bool = true,
        onReload: (@MainActor () async -> Void)? = nil,
        onAuthorize: (@MainActor (Browser) async -> Void)? = nil,
        onRetry: (@MainActor (BookmarkSourceID) async -> Void)? = nil,
        onShowSynchronization: (() -> Void)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        _authorizationViewModel = State(
            initialValue: authorizationViewModel
        )
        _searchModel = State(initialValue: SearchViewModel(engine: searchEngine))
        self.synchronizationSummary = synchronizationSummary
        self.loadsOnAppear = loadsOnAppear
        self.onReload = onReload
        self.onAuthorize = onAuthorize
        self.onRetry = onRetry
        self.onShowSynchronization = onShowSynchronization
    }

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationDestination(for: ExplorerStep.self) { step in
                    explorerDestination(for: step, path: $path)
                }
                .navigationTitle("Accueil")
                .toolbar {
                    ToolbarItem {
                        Button {
                            onShowSynchronization?()
                        } label: {
                            Label(
                                "Synchronisation",
                                systemImage: "arrow.triangle.2.circlepath"
                            )
                        }
                        .disabled(onShowSynchronization == nil)
                        .accessibilityLabel(
                            "Ouvrir la prévisualisation de la synchronisation"
                        )
                    }
                    ToolbarItem {
                        Button {
                            Task { await reloadDashboard() }
                        } label: {
                            Label(
                                "Actualiser",
                                systemImage: "arrow.clockwise"
                            )
                        }
                        .disabled(viewModel.isLoading)
                        .accessibilityLabel(
                            "Actualiser tous les navigateurs"
                        )
                    }
                }
                .searchable(
                    text: $searchModel.query,
                    prompt: "Rechercher un favori"
                )
                .onChange(
                    of: viewModel.searchableSources,
                    initial: true
                ) { _, sources in
                    searchModel.updateSources(sources)
                }
        }
        .task {
            guard loadsOnAppear else { return }
            await authorizationViewModel?.restore()
            await viewModel.load()
        }
    }

    @ViewBuilder
    private var content: some View {
        if searchModel.hasQuery {
            SearchResultsView(model: searchModel, onSelect: openResult)
        } else {
            dashboard
        }
    }

    private var dashboard: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                if let authorizationViewModel {
                    ApplicationAuthorizationCard(
                        model: authorizationViewModel,
                        onAuthorize: { browser in
                            Task { await authorize(browser) }
                        }
                    )
                }

                if viewModel.sources.isEmpty {
                    EmptyStateView(
                        title: "Aucun navigateur configuré",
                        message: "Aucune source de favoris n'est disponible.",
                        systemImage: "bookmark.slash"
                    )
                    .frame(maxWidth: .infinity, minHeight: 240)
                } else {
                    ForEach(viewModel.sources) { entry in
                        SourceCard(
                            entry: entry,
                            tree: viewModel.tree(for: entry.id),
                            onAuthorize: {
                                Task {
                                    await authorize(
                                        entry.source.browser
                                    )
                                }
                            },
                            onRetry: {
                                Task { await retry(entry.id) }
                            }
                        )
                    }
                }

                DashboardSynchronizationCard(
                    summary: synchronizationSummary,
                    onShowSynchronization: onShowSynchronization
                )
            }
            .frame(
                maxWidth: Theme.Size.contentMaxWidth,
                alignment: .leading
            )
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    private func openResult(_ result: BookmarkSearchResult) {
        guard let tree = viewModel.tree(for: result.source.id) else {
            return
        }
        path = ExplorerStep.path(to: result, in: tree)
    }

    private func reloadDashboard() async {
        if let onReload {
            await onReload()
        } else {
            await authorizationViewModel?.restore()
            await viewModel.reloadAll()
        }
    }

    private func authorize(_ browser: Browser) async {
        if let onAuthorize {
            await onAuthorize(browser)
        } else if let authorizationViewModel {
            await authorizationViewModel.authorize(browser)
            await viewModel.reloadAll()
        } else {
            await viewModel.authorize(
                BookmarkSource.singleProfile(browser).id
            )
        }
    }

    private func retry(_ sourceID: BookmarkSourceID) async {
        if let onRetry {
            await onRetry(sourceID)
        } else {
            await viewModel.retry(sourceID)
        }
    }
}

private struct ApplicationAuthorizationCard: View {
    let model: ApplicationAuthorizationViewModel
    let onAuthorize: (Browser) -> Void

    var body: some View {
        PermissionCard(statusSymbol: statusSymbol) {
            if model.isLoading {
                HStack(spacing: Theme.Spacing.s) {
                    ProgressView().controlSize(.small)
                    Text("Vérification des autorisations…")
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(statusMessage)
                    .foregroundStyle(statusColor)
                browserRow(.safari)
                browserRow(.chrome)
            }
        }
    }

    private var statusSymbol: String {
        switch model.state.status {
        case .complete: "checkmark.shield.fill"
        case .absent, .partial: "lock"
        case .invalidBookmark, .accessError:
            "exclamationmark.triangle.fill"
        }
    }

    private var statusMessage: String {
        switch model.state.status {
        case .absent:
            "BookmarkBridge a besoin d'accéder aux favoris Safari et au profil Chrome sélectionné."
        case .partial:
            "Une autorisation reste nécessaire."
        case .complete:
            "Les accès Safari et Chrome sont disponibles."
        case .invalidBookmark:
            "Une autorisation enregistrée n'est plus valide."
        case .accessError:
            "Un emplacement autorisé n'est pas accessible."
        }
    }

    private var statusColor: Color {
        switch model.state.status {
        case .complete: Theme.Palette.green
        case .invalidBookmark, .accessError: Theme.Palette.error
        case .absent, .partial: .secondary
        }
    }

    @ViewBuilder
    private func browserRow(_ browser: Browser) -> some View {
        let state = model.state.state(for: browser)
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: symbol(for: state))
                .foregroundStyle(color(for: state))
                .accessibilityHidden(true)
            Text(browser.displayName)
            Spacer()
            if state != .valid {
                PrimaryActionButton(buttonTitle(for: browser)) {
                    onAuthorize(browser)
                }
                .disabled(model.isLoading)
            } else {
                Text("Autorisé")
                    .font(.callout)
                    .foregroundStyle(Theme.Palette.green)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func buttonTitle(for browser: Browser) -> LocalizedStringKey {
        switch browser {
        case .safari: "Choisir les favoris Safari"
        case .chrome: "Choisir le profil Chrome"
        }
    }

    private func symbol(
        for state: BrowserAuthorizationState
    ) -> String {
        switch state {
        case .valid: "checkmark.circle.fill"
        case .missing: "circle.dashed"
        case .invalidBookmark, .accessError:
            "exclamationmark.circle.fill"
        }
    }

    private func color(
        for state: BrowserAuthorizationState
    ) -> Color {
        switch state {
        case .valid: Theme.Palette.green
        case .missing: .secondary
        case .invalidBookmark, .accessError: Theme.Palette.error
        }
    }
}

private struct DashboardSynchronizationCard: View {
    let summary: DashboardSynchronizationSummary
    let onShowSynchronization: (() -> Void)?

    var body: some View {
        SynchronizationSummaryCard {
            summaryContent
            if let onShowSynchronization {
                SecondaryActionButton(
                    "Voir la prévisualisation",
                    systemImage: "chevron.forward",
                    action: onShowSynchronization
                )
                .accessibilityHint(
                    "Ouvre le détail de la synchronisation"
                )
            }
        }
    }

    @ViewBuilder
    private var summaryContent: some View {
        switch summary {
        case .idle:
            Label(
                "Prévisualisation en attente.",
                systemImage: "eye"
            )
            .foregroundStyle(.secondary)
        case .loading:
            HStack(spacing: Theme.Spacing.s) {
                ProgressView().controlSize(.small)
                Text("Calcul de la prévisualisation…")
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel(
                "Calcul de la prévisualisation en cours"
            )
        case .changes(let count):
            Label(
                "\(count) changement\(count == 1 ? "" : "s") à vérifier",
                systemImage: "exclamationmark.circle"
            )
        case .upToDate:
            Label(
                "Les navigateurs sont synchronisés",
                systemImage: "checkmark.circle.fill"
            )
            .foregroundStyle(Theme.Palette.green)
        case .failed(let message):
            ErrorStateView(message: message, onRetry: nil)
        }
    }
}

private struct SourceCard: View {
    let entry: DashboardViewModel.SourceState
    let tree: BookmarkTree?
    let onAuthorize: () -> Void
    let onRetry: () -> Void

    var body: some View {
        StatusCard(
            entry.source.displayName,
            systemImage: symbolName
        ) {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch entry.status {
        case .loading:
            HStack(spacing: Theme.Spacing.s) {
                ProgressView().controlSize(.small)
                Text("Lecture des favoris…")
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Lecture des favoris en cours")
        case .loaded(let summary):
            loadedState(summary)
        case .authorizationRequired:
            authorizationRequiredState
        case .failed(let message):
            ErrorStateView(message: message, onRetry: onRetry)
                .accessibilityLabel(
                    "Erreur pour \(entry.source.displayName) : \(message)"
                )
        }
    }

    private func loadedState(
        _ summary: BrowserBookmarkSummary
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(alignment: .top, spacing: Theme.Spacing.s) {
                StatisticCard(
                    value: summary.folderCount,
                    label: "Dossiers"
                )
                StatisticCard(
                    value: summary.bookmarkCount,
                    label: "Favoris"
                )
                StatisticCard(
                    value: summary.nodeCount,
                    label: "Nœuds"
                )
            }
            Text(
                "Lu le \(summary.capturedAt.formatted(date: .abbreviated, time: .shortened))"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityLabel(
                "Dernière lecture le \(summary.capturedAt.formatted(date: .long, time: .standard))"
            )
            if let tree {
                NavigationLink(
                    value: ExplorerStep.source(entry.source, tree)
                ) {
                    Label(
                        "Explorer les favoris",
                        systemImage: "chevron.forward"
                    )
                    .font(.callout.weight(.medium))
                    .frame(
                        minHeight: Theme.Size.minimumInteractive
                    )
                }
                .accessibilityLabel(
                    "Explorer les favoris de \(entry.source.displayName)"
                )
            }
        }
    }

    private var authorizationRequiredState: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Label(
                "BookmarkBridge a besoin d'accéder aux favoris.",
                systemImage: "lock"
            )
            .foregroundStyle(.secondary)
            PrimaryActionButton("Autoriser l'accès…") {
                onAuthorize()
            }
            .accessibilityLabel(
                "Autoriser l'accès aux favoris \(entry.source.displayName)"
            )
        }
    }

    private var symbolName: String {
        switch entry.source.browser {
        case .safari: "safari"
        case .chrome: "globe"
        }
    }
}

#Preview("Dashboard (in-memory)") {
    DashboardView(
        viewModel: DashboardViewModel(providers: [
            SafariSourceProvider(
                reader: InMemoryBookmarkReader(
                    browser: .safari,
                    tree: .sample(for: .safari)
                )
            ),
        ])
    )
}
