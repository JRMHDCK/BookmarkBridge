//
//  SynchronizationPreviewScreen.swift
//  BookmarkBridge
//

import SwiftUI

/// Dedicated home for the BSE preview. It renders presentation models only and
/// delegates refresh and confirmed execution to the application coordinator.
struct SynchronizationPreviewScreen: View {
    let model: SynchronizationViewModel
    let isAuthorized: Bool
    let onReload: @MainActor () async -> Void
    let onSynchronize: @MainActor () async -> Bool
    let onBack: (() -> Void)?
    let allowsSynchronization: Bool

    init(
        model: SynchronizationViewModel,
        isAuthorized: Bool,
        onReload: @escaping @MainActor () async -> Void,
        onSynchronize: @escaping @MainActor () async -> Bool,
        onBack: (() -> Void)? = nil,
        allowsSynchronization: Bool = true
    ) {
        self.model = model
        self.isAuthorized = isAuthorized
        self.onReload = onReload
        self.onSynchronize = onSynchronize
        self.onBack = onBack
        self.allowsSynchronization = allowsSynchronization
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                ScreenHeader(
                    DocumentationText.value("synchronization.title"),
                    subtitle: DocumentationText.value("preview.subtitle")
                )
                SynchronizationSummaryCard(
                    DocumentationText.value("preview.summary")
                ) {
                    executionStatus
                    previewContent
                }
                .contentTransition(.opacity)
                .animation(Theme.Motion.stateChange, value: model.state)
                .animation(
                    Theme.Motion.stateChange,
                    value: model.executionState
                )
            }
            .frame(
                maxWidth: Theme.Size.contentMaxWidth,
                alignment: .leading
            )
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .navigationTitle(DocumentationText.value("synchronization.title"))
        .toolbar {
            if let onBack {
                ToolbarItem(placement: .navigation) {
                    Button {
                        onBack()
                    } label: {
                        Label(
                            DocumentationText.value("action.back"),
                            systemImage: "chevron.left"
                        )
                    }
                    .disabled(model.isSynchronizing)
                    .help(DocumentationText.value("preview.back.tooltip"))
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task { await onReload() }
                } label: {
                    Label(
                        DocumentationText.value("preview.reload"),
                        systemImage: "arrow.clockwise"
                    )
                }
                .disabled(model.isSynchronizing)
                .help(
                    DocumentationText.value(
                        "tooltip.scan"
                    )
                )

                ContextualHelpButton(pageID: .synchronization)
            }
        }
    }

    @ViewBuilder
    private var executionStatus: some View {
        switch model.executionState {
        case .idle:
            EmptyView()
        case .completed:
            SuccessStateView(
                message: DocumentationText.value("sync.completed")
            )
        case .preparing:
            LoadingStateView(
                message: DocumentationText.value("sync.preparing")
            )
        case .writing:
            LoadingStateView(
                message: DocumentationText.value("sync.inProgress")
            )
        case .validating:
            LoadingStateView(
                message: DocumentationText.value("sync.validating")
            )
        case .failed(let message):
            synchronizationFailure(message)
        }
    }

    private func synchronizationFailure(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Label(
                DocumentationText.value("sync.interrupted"),
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.headline)
            .foregroundStyle(Theme.Palette.error)
            .symbolRenderingMode(.hierarchical)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var previewContent: some View {
        switch model.state {
        case .idle:
            EmptyStateView(
                title: DocumentationText.value("preview.unavailable.title"),
                message: DocumentationText.value("preview.unavailable.message"),
                systemImage: "bookmark.slash"
            )
            .frame(minHeight: Theme.Size.emptyStateMinimumHeight)
        case .loading:
            LoadingStateView(
                message: DocumentationText.value("preview.calculating")
            )
                .accessibilityLabel(
                    DocumentationText.value("preview.calculating.accessibility")
                )
        case .loaded(let preview):
            detailedPreview(preview, isEmpty: false)
        case .empty(let preview):
            detailedPreview(preview, isEmpty: true)
        case .failed(let message):
            ErrorStateView(
                message: message,
                onRetry: { Task { await onReload() } }
            )
        }
    }

    private func detailedPreview(
        _ preview: SynchronizationPreviewPresentation,
        isEmpty: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            browserRelationship(preview)

            if isEmpty && model.executionState != .completed {
                SuccessStateView(
                    message: DocumentationText.value("preview.upToDate")
                )
            } else {
                if !isEmpty {
                    Text(operationCount(preview.totalOperationCount))
                    .font(.callout.weight(.medium))
                }
            }

            SynchronizationStatistics(preview: preview)

            if !isEmpty {
                if allowsSynchronization {
                    PrimaryActionButton(
                        DocumentationText.value("action.synchronize"),
                        systemImage: "arrow.triangle.2.circlepath"
                    ) {
                        Task { _ = await onSynchronize() }
                    }
                    .disabled(!isAuthorized || !model.canSynchronize)
                    .accessibilityHint(
                        DocumentationText.value("preview.apply.hint")
                    )
                    .help(synchronizationHelp)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                } else {
                    Label(
                        DocumentationText.value("preview.safariWritingSoon"),
                        systemImage: "clock"
                    )
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }

    private func browserRelationship(
        _ preview: SynchronizationPreviewPresentation
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Spacing.s) {
                browserSummary(
                    preview.source,
                    role: DocumentationText.value("common.source")
                )
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                browserSummary(
                    preview.target,
                    role: DocumentationText.value("common.target")
                )
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                browserSummary(
                    preview.source,
                    role: DocumentationText.value("common.source")
                )
                Image(systemName: "arrow.down")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                browserSummary(
                    preview.target,
                    role: DocumentationText.value("common.target")
                )
            }
        }
    }

    private func browserSummary(
        _ summary: SynchronizationBrowserSummary,
        role: String
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(role)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(summary.name)
                .font(.callout.weight(.medium))
            Text(itemCounts(summary.bookmarkCount, summary.folderCount))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var synchronizationHelp: String {
        if !isAuthorized {
            return DocumentationText.value("sync.authorizeFirst")
        }
        if model.isSynchronizing {
            return DocumentationText.value("sync.alreadyInProgress")
        }
        return DocumentationText.value("tooltip.synchronize")
    }

    private func operationCount(_ count: Int) -> String {
        DocumentationText.formatted(
            count == 1 ? "preview.operation.one" : "preview.operation.other",
            count
        )
    }

    private func itemCounts(_ bookmarks: Int, _ folders: Int) -> String {
        DocumentationText.formatted(
            "common.itemCounts",
            bookmarks,
            folders
        )
    }
}

private struct SynchronizationStatistics: View {
    let preview: SynchronizationPreviewPresentation

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: Theme.Spacing.s) {
                creation
                deletion
                move
                rename
                update
            }
            .fixedSize(horizontal: true, vertical: false)

            Grid(
                alignment: .leading,
                horizontalSpacing: Theme.Spacing.l,
                verticalSpacing: Theme.Spacing.m
            ) {
                GridRow {
                    creation
                    deletion
                }
                GridRow {
                    move
                    rename
                }
                GridRow {
                    update
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var creation: some View {
        statistic(
            value: preview.creationCount,
            label: DocumentationText.value("preview.stat.creations"),
            systemImage: "plus"
        )
    }

    private var deletion: some View {
        statistic(
            value: preview.deletionCount,
            label: DocumentationText.value("preview.stat.deletions"),
            systemImage: "trash"
        )
    }

    private var move: some View {
        statistic(
            value: preview.moveCount,
            label: DocumentationText.value("preview.stat.moves"),
            systemImage: "arrow.right"
        )
    }

    private var rename: some View {
        statistic(
            value: preview.renameCount,
            label: DocumentationText.value("preview.stat.renames"),
            systemImage: "pencil"
        )
    }

    private var update: some View {
        statistic(
            value: preview.urlModificationCount,
            label: DocumentationText.value("preview.stat.updates"),
            systemImage: "link"
        )
    }

    private func statistic(
        value: Int,
        label: String,
        systemImage: String
    ) -> some View {
        StatisticCard(
            value: value,
            label: label,
            systemImage: systemImage,
            prominent: false
        )
        .frame(
            minWidth: Theme.Size.statisticMinimumWidth,
            alignment: .leading
        )
    }
}
