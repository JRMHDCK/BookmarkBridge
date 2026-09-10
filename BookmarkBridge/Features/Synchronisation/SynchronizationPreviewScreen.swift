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
    let onReportError: @MainActor () async -> Void
    let onBack: (() -> Void)?
    let allowsSynchronization: Bool
    @State private var expandedSections: Set<SynchronizationPreviewSectionKind> = []

    init(
        model: SynchronizationViewModel,
        isAuthorized: Bool,
        onReload: @escaping @MainActor () async -> Void,
        onSynchronize: @escaping @MainActor () async -> Bool,
        onReportError: @escaping @MainActor () async -> Void,
        onBack: (() -> Void)? = nil,
        allowsSynchronization: Bool = true
    ) {
        self.model = model
        self.isAuthorized = isAuthorized
        self.onReload = onReload
        self.onSynchronize = onSynchronize
        self.onReportError = onReportError
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
                topPrimaryAction
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
        .onAppear { expandedSections.removeAll() }
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
    private var topPrimaryAction: some View {
        if case .awaitingSafariImport = model.executionState {
            PrimaryActionRow {
                PrimaryActionButton(
                    DocumentationText.value("safariImport.action.openSafari"),
                    systemImage: "safari"
                ) {
                    model.openSafariForPreparedImport()
                }
            }
        } else if allowsSynchronization,
           case .loaded(let preview) = model.state,
           preview.totalOperationCount > 0 {
            PrimaryActionRow {
                PrimaryActionButton(
                    synchronizationActionTitle,
                    systemImage: model.previewDirection == .chromeToSafari
                        ? "square.and.arrow.down"
                        : "arrow.triangle.2.circlepath"
                ) {
                    Task { _ = await onSynchronize() }
                }
                .disabled(!isAuthorized || !model.canSynchronize)
                .accessibilityHint(
                    DocumentationText.value("preview.apply.hint")
                )
                .help(synchronizationHelp)
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
        case .awaitingSafariImport(let importPresentation):
            safariImportInstructions(importPresentation)
        case .failed(let message):
            synchronizationFailure(message)
        }
    }

    private func safariImportInstructions(
        _ importPresentation: SafariImportPresentation
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Label(
                DocumentationText.value("safariImport.ready.title"),
                systemImage: "safari"
            )
            .font(.headline)
            .foregroundStyle(Theme.Palette.green)

            Text(DocumentationText.formatted(
                "safariImport.ready.summary",
                importPresentation.bookmarkCount,
                importPresentation.folderCount
            ))
            .font(.callout)

            Text(DocumentationText.value("safariImport.ready.instructions"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if importPresentation.skippedBookmarkCount > 0
                    || importPresentation.unsupportedOperationCount > 0 {
                Label(
                    DocumentationText.formatted(
                        "safariImport.ready.limitations",
                        importPresentation.skippedBookmarkCount,
                        importPresentation.unsupportedOperationCount
                    ),
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(Theme.Palette.warning)
            }

            HStack(spacing: Theme.Spacing.s) {
                SecondaryActionButton(
                    DocumentationText.value("safariImport.action.showFile"),
                    systemImage: "folder"
                ) {
                    model.revealPreparedSafariImport()
                }
            }
        }
        .accessibilityElement(children: .contain)
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
            HStack(spacing: Theme.Spacing.s) {
                SecondaryActionButton(
                    DocumentationText.value("action.retry")
                ) {
                    Task { _ = await onSynchronize() }
                }
                SecondaryActionButton(
                    DocumentationText.value(
                        "bugReport.action.reportError"
                    ),
                    systemImage: "ladybug"
                ) {
                    Task { await onReportError() }
                }
                .accessibilityIdentifier("bug-report.contextual")
                .accessibilityHint(
                    DocumentationText.value(
                        "bugReport.accessibility.hint"
                    )
                )
            }
        }
        .accessibilityElement(children: .contain)
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
                onRetry: { Task { await onReload() } },
                onReportError: { Task { await onReportError() } }
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
                if preview.hasUnsupportedChanges {
                    Label(
                        DocumentationText.value("safariImport.preview.noApplicableChanges"),
                        systemImage: "info.circle"
                    )
                    .foregroundStyle(.secondary)
                } else {
                    SuccessStateView(
                        message: DocumentationText.value("preview.upToDate")
                    )
                }
            } else {
                if !isEmpty {
                    Text(operationCount(preview.totalOperationCount))
                    .font(.callout.weight(.medium))
                }
            }

            SynchronizationChangeCards(
                preview: preview,
                expandedSections: $expandedSections
            )

            if !isEmpty {
                if model.previewDirection == .chromeToSafari {
                    Label(
                        DocumentationText.value(
                            "safariImport.preview.additiveNotice"
                        ),
                        systemImage: "info.circle"
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }

                if !allowsSynchronization {
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
        if model.previewDirection == .chromeToSafari {
            return DocumentationText.value("safariImport.action.help")
        }
        return DocumentationText.value("tooltip.synchronize")
    }

    private var synchronizationActionTitle: String {
        if model.previewDirection == .chromeToSafari {
            return DocumentationText.value("safariImport.action.prepare")
        }
        return DocumentationText.value("action.synchronize")
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

private struct SynchronizationChangeCards: View {
    let preview: SynchronizationPreviewPresentation
    @Binding var expandedSections: Set<SynchronizationPreviewSectionKind>

    var body: some View {
        LazyVStack(alignment: .leading, spacing: Theme.Spacing.m) {
            ForEach(preview.sections, id: \.self) {
                section in
                SynchronizationChangeCard(
                    section: section,
                    items: preview.items(in: section),
                    isExpanded: Binding(
                        get: { expandedSections.contains(section) },
                        set: { expanded in
                            if expanded {
                                expandedSections.insert(section)
                            } else {
                                expandedSections.remove(section)
                            }
                        }
                    )
                )
            }
        }
    }
}

private struct SynchronizationChangeCard: View {
    let section: SynchronizationPreviewSectionKind
    let items: [SynchronizationPreviewItem]

    @Binding var isExpanded: Bool

    var body: some View {
        GroupBox {
            DisclosureGroup(isExpanded: $isExpanded) {
                if !items.isEmpty {
                    Divider()
                        .padding(.top, Theme.Spacing.s)
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) {
                            index, item in
                            changeRow(item)
                            if index < items.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: Theme.Spacing.s) {
                    Label(title, systemImage: systemImage)
                        .font(.headline)
                    Spacer()
                    Text(verbatim: String(items.count))
                        .font(.callout.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, Theme.Spacing.s)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(.quaternary, in: Capsule())
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func changeRow(_ item: SynchronizationPreviewItem) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.s) {
            Image(systemName: item.isFolder ? "folder" : "bookmark")
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(item.title)
                    .font(.callout.weight(.medium))
                    .textSelection(.enabled)
                if let detail = item.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                if let url = item.url {
                    Link(destination: url) {
                        Text(url.absoluteString)
                            .font(.caption)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
        }
        .padding(.vertical, Theme.Spacing.s)
    }

    private var title: String {
        switch section {
        case .creation:
            DocumentationText.value("preview.stat.creations")
        case .deletion:
            DocumentationText.value("preview.stat.deletions")
        case .move:
            DocumentationText.value("preview.stat.moves")
        case .rename:
            DocumentationText.value("preview.stat.renames")
        case .update:
            DocumentationText.value("preview.stat.updates")
        }
    }

    private var systemImage: String {
        switch section {
        case .creation: "plus.circle"
        case .deletion: "trash"
        case .move: "arrow.right.circle"
        case .rename: "pencil"
        case .update: "link"
        }
    }
}
