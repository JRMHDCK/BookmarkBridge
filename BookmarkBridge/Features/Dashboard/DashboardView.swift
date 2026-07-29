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
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button {
                            Task { await reloadDashboard() }
                        } label: {
                            Label(
                                "Actualiser",
                                systemImage: "arrow.clockwise"
                            )
                        }
                        .disabled(viewModel.isLoading)
                        .help("Actualiser les favoris")

                        Button {
                            onShowSynchronization?()
                        } label: {
                            Label(
                                "Synchronisation",
                                systemImage:
                                    "arrow.triangle.2.circlepath"
                            )
                        }
                        .disabled(onShowSynchronization == nil)
                        .help("Ouvrir la synchronisation")
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
        Group {
            if searchModel.hasQuery {
                SearchResultsView(model: searchModel, onSelect: openResult)
            } else {
                dashboard
            }
        }
        .contentTransition(.opacity)
        .animation(
            Theme.Motion.quick,
            value: searchModel.hasQuery
        )
    }

    private var dashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                ScreenHeader(
                    "Vue d’ensemble",
                    subtitle:
                        "État de vos favoris Safari et Chrome."
                )

                DashboardSynchronizationCard(
                    summary: synchronizationSummary,
                    onShowSynchronization: onShowSynchronization
                )

                if let authorizationViewModel {
                    ApplicationAuthorizationCard(
                        model: authorizationViewModel,
                        onAuthorize: { browser in
                            Task { await authorize(browser) }
                        }
                    )
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    SectionHeader("Sources")

                    if viewModel.sources.isEmpty {
                        EmptyStateView(
                            title: "Aucun navigateur configuré",
                            message:
                                "Aucune source de favoris n'est disponible.",
                            systemImage: "bookmark.slash"
                        )
                        .frame(
                            maxWidth: .infinity,
                            minHeight: Theme.Size.emptyStateMinimumHeight
                        )
                    } else {
                        VStack(spacing: Theme.Spacing.zero) {
                            ForEach(
                                Array(viewModel.sources.enumerated()),
                                id: \.element.id
                            ) { index, entry in
                                SourceRow(
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
                                if index < viewModel.sources.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                }
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
        Group {
            if model.state.status == .complete && !model.isLoading {
                EmptyView()
            } else {
                PermissionCard(statusSymbol: statusSymbol) {
                    if model.isLoading {
                        LoadingStateView(
                            message: "Vérification des autorisations…"
                        )
                    } else {
                        Text(statusMessage)
                            .foregroundStyle(statusColor)
                        browserRow(.safari)
                        browserRow(.chrome)
                    }
                }
            }
        }
        .contentTransition(.opacity)
        .animation(Theme.Motion.stateChange, value: model.state.status)
        .animation(Theme.Motion.quick, value: model.isLoading)
    }

    private var statusSymbol: String {
        switch model.state.status {
        case .complete: "checkmark.shield"
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
        case .complete: .secondary
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
                SecondaryActionButton(buttonTitle(for: browser)) {
                    onAuthorize(browser)
                }
                .disabled(model.isLoading)
            } else {
                Text("Autorisé")
                    .font(.callout)
                    .foregroundStyle(.secondary)
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
        case .valid: "checkmark.circle"
        case .missing: "circle.dashed"
        case .invalidBookmark, .accessError:
            "exclamationmark.circle.fill"
        }
    }

    private func color(
        for state: BrowserAuthorizationState
    ) -> Color {
        switch state {
        case .valid: .secondary
        case .missing: .secondary
        case .invalidBookmark, .accessError: Theme.Palette.error
        }
    }
}

private struct DashboardSynchronizationCard: View {
    let summary: DashboardSynchronizationSummary
    let onShowSynchronization: (() -> Void)?

    var body: some View {
        SynchronizationSummaryCard("État de la synchronisation") {
            Text("Safari → Chrome")
                .font(Theme.Typography.metadata)
                .foregroundStyle(.secondary)
            summaryContent
            if let onShowSynchronization {
                PrimaryActionButton(
                    "Examiner les changements",
                    systemImage: "arrow.right",
                    action: onShowSynchronization
                )
                .accessibilityHint(
                    "Ouvre le détail de la synchronisation"
                )
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .contentTransition(.opacity)
        .animation(Theme.Motion.stateChange, value: summary)
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
            LoadingStateView(
                message: "Calcul de la prévisualisation…"
            )
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
                systemImage: "checkmark.circle"
            )
            .foregroundStyle(Theme.Palette.green)
        case .failed(let message):
            ErrorStateView(message: message, onRetry: nil)
        }
    }
}

private struct SourceRow: View {
    let entry: DashboardViewModel.SourceState
    let tree: BookmarkTree?
    let onAuthorize: () -> Void
    let onRetry: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.l) {
            Image(systemName: symbolName)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: Theme.Size.minimumInteractive)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text(entry.source.displayName)
                    .font(.headline)
                content
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.Spacing.m)
        .contentTransition(.opacity)
        .animation(Theme.Motion.quick, value: entry.status)
    }

    @ViewBuilder
    private var content: some View {
        switch entry.status {
        case .loading:
            LoadingStateView(message: "Lecture des favoris…")
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
            Text(
                "\(summary.bookmarkCount) favoris · \(summary.folderCount) dossiers"
            )
            .font(.callout)
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
                        systemImage: "arrow.right"
                    )
                    .font(.callout)
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
            SecondaryActionButton("Autoriser l'accès…") {
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
