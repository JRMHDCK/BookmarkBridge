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
                .navigationTitle(DocumentationText.value("dashboard.title"))
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button {
                            Task { await reloadDashboard() }
                        } label: {
                            Label(
                                DocumentationText.value("action.reload"),
                                systemImage: "arrow.clockwise"
                            )
                        }
                        .disabled(viewModel.isLoading)
                        .help(
                            DocumentationText.value(
                                "tooltip.reload"
                            )
                        )

                        Button {
                            onShowSynchronization?()
                        } label: {
                            Label(
                                DocumentationText.value("synchronization.title"),
                                systemImage:
                                    "arrow.triangle.2.circlepath"
                            )
                        }
                        .disabled(onShowSynchronization == nil)
                        .help(
                            DocumentationText.value(
                                "tooltip.synchronization"
                            )
                        )

                        ContextualHelpButton(pageID: .introduction)
                    }
                }
                .searchable(
                    text: $searchModel.query,
                    prompt: DocumentationText.value("dashboard.search.prompt")
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
                    DocumentationText.value("dashboard.overview.title"),
                    subtitle: DocumentationText.value(
                        "dashboard.overview.subtitle"
                    )
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
                    SectionHeader(
                        DocumentationText.value("dashboard.sources")
                    )

                    if viewModel.sources.isEmpty {
                        EmptyStateView(
                            title: DocumentationText.value(
                                "dashboard.empty.title"
                            ),
                            message: DocumentationText.value(
                                "dashboard.empty.message"
                            ),
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
                            message: DocumentationText.value(
                                "authorization.checking"
                            )
                        )
                    } else if model.state.status == .invalidBookmark
                        || model.state.status == .accessError {
                        UserFacingErrorDetails(
                            presentation: .authorization
                        )
                        browserRow(.safari)
                        browserRow(.chrome)
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
            DocumentationText.value("authorization.status.absent")
        case .partial:
            DocumentationText.value("authorization.status.partial")
        case .complete:
            DocumentationText.value("authorization.status.complete")
        case .invalidBookmark:
            DocumentationText.value("authorization.status.invalid")
        case .accessError:
            DocumentationText.value("authorization.status.error")
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
                .help(
                    DocumentationText.value(
                        browser == .safari
                            ? "tooltip.authorize.safari"
                            : "tooltip.authorize.chrome"
                    )
                )
            } else {
                Text(DocumentationText.value("authorization.authorized"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func buttonTitle(for browser: Browser) -> String {
        switch browser {
        case .safari:
            DocumentationText.value("authorization.chooseSafari")
        case .chrome:
            DocumentationText.value("authorization.chooseChrome")
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
        SynchronizationSummaryCard(
            DocumentationText.value("dashboard.syncStatus.title")
        ) {
            Text(
                DocumentationText.value("synchronization.bidirectional.short")
            )
                .font(Theme.Typography.metadata)
                .foregroundStyle(.secondary)
            summaryContent
            if let onShowSynchronization {
                PrimaryActionButton(
                    DocumentationText.value("dashboard.reviewChanges"),
                    systemImage: "arrow.right",
                    action: onShowSynchronization
                )
                .accessibilityHint(
                    DocumentationText.value("dashboard.reviewChanges.hint")
                )
                .help(
                    DocumentationText.value(
                        "tooltip.compare"
                    )
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
                DocumentationText.value("dashboard.preview.pending"),
                systemImage: "eye"
            )
            .foregroundStyle(.secondary)
        case .loading:
            LoadingStateView(
                message: DocumentationText.value("preview.calculating")
            )
            .accessibilityLabel(
                DocumentationText.value("preview.calculating.accessibility")
            )
        case .changes(let count):
            Label(
                changeCount(count),
                systemImage: "exclamationmark.circle"
            )
        case .upToDate:
            Label(
                DocumentationText.value("preview.upToDate"),
                systemImage: "checkmark.circle"
            )
            .foregroundStyle(Theme.Palette.green)
        case .failed(let message):
            ErrorStateView(message: message, onRetry: nil)
        }
    }

    private func changeCount(_ count: Int) -> String {
        DocumentationText.formatted(
            count == 1
                ? "dashboard.change.one"
                : "dashboard.change.other",
            count
        )
    }
}

private struct SourceRow: View {
    let entry: DashboardViewModel.SourceState
    let tree: BookmarkTree?
    let onAuthorize: () -> Void
    let onRetry: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.l) {
            BrowserLogo(
                browser: entry.source.browser,
                size: 32
            )
                .frame(width: Theme.Size.minimumInteractive)
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
            LoadingStateView(
                message: DocumentationText.value("dashboard.reading")
            )
            .accessibilityLabel(
                DocumentationText.value("dashboard.reading.accessibility")
            )
        case .loaded(let summary):
            loadedState(summary)
        case .authorizationRequired:
            authorizationRequiredState
        case .failed(let message):
            ErrorStateView(message: message, onRetry: onRetry)
                .accessibilityLabel(
                    DocumentationText.formatted(
                        "dashboard.sourceError",
                        entry.source.displayName,
                        message
                    )
                )
        }
    }

    private func loadedState(
        _ summary: BrowserBookmarkSummary
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text(
                DocumentationText.formatted(
                    "common.itemCounts",
                    summary.bookmarkCount,
                    summary.folderCount
                )
            )
            .font(.callout)
            Text(
                DocumentationText.formatted(
                    "dashboard.readAt",
                    summary.capturedAt.formatted(
                        date: .abbreviated,
                        time: .shortened
                    )
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityLabel(
                DocumentationText.formatted(
                    "dashboard.lastRead.accessibility",
                    summary.capturedAt.formatted(
                        date: .long,
                        time: .standard
                    )
                )
            )
            if let tree {
                NavigationLink(
                    value: ExplorerStep.source(entry.source, tree)
                ) {
                    Label(
                        DocumentationText.value("dashboard.explore"),
                        systemImage: "arrow.right"
                    )
                    .font(.callout)
                    .frame(
                        minHeight: Theme.Size.minimumInteractive
                    )
                }
                .accessibilityLabel(
                    DocumentationText.formatted(
                        "dashboard.explore.accessibility",
                        entry.source.displayName
                    )
                )
            }
        }
    }

    private var authorizationRequiredState: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Label(
                DocumentationText.value("authorization.required"),
                systemImage: "lock"
            )
            .foregroundStyle(.secondary)
            SecondaryActionButton(
                DocumentationText.value("authorization.action")
            ) {
                onAuthorize()
            }
            .accessibilityLabel(
                DocumentationText.formatted(
                    "authorization.action.accessibility",
                    entry.source.displayName
                )
            )
            .help(
                DocumentationText.value(
                    entry.source.browser == .safari
                        ? "tooltip.authorize.safari"
                        : "tooltip.authorize.chrome"
                )
            )
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
    .environment(DocumentationRouter())
}
