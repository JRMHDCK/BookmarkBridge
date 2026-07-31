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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                ScreenHeader(
                    "Synchronisation",
                    subtitle:
                        "Vérifiez chaque changement avant de l’appliquer."
                )
                SynchronizationSummaryCard("Résumé") {
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
        .navigationTitle("Synchronisation")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task { await onReload() }
                } label: {
                    Label(
                        "Actualiser la prévisualisation",
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
            SuccessStateView(message: "Synchronisation terminée")
        case .preparing:
            LoadingStateView(
                message: "Préparation de la synchronisation…"
            )
        case .writing:
            LoadingStateView(message: "Synchronisation en cours…")
        case .validating:
            LoadingStateView(
                message: "Validation de la synchronisation…"
            )
        case .failed(let message):
            synchronizationFailure(message)
        }
    }

    private func synchronizationFailure(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Label(
                "Synchronisation interrompue",
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
                title: "Prévisualisation indisponible",
                message: "Chargez Safari et Chrome pour préparer la synchronisation.",
                systemImage: "bookmark.slash"
            )
            .frame(minHeight: Theme.Size.emptyStateMinimumHeight)
        case .loading:
            LoadingStateView(
                message: "Calcul de la prévisualisation…"
            )
                .accessibilityLabel(
                    "Calcul de la prévisualisation en cours"
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
                    message: "Les navigateurs sont synchronisés"
                )
            } else {
                if !isEmpty {
                    Text(
                        "\(preview.totalOperationCount) changement\(preview.totalOperationCount == 1 ? "" : "s") détecté\(preview.totalOperationCount == 1 ? "" : "s")"
                    )
                    .font(.callout.weight(.medium))
                }
            }

            SynchronizationStatistics(preview: preview)

            if !isEmpty {
                PrimaryActionButton(
                    "Synchroniser",
                    systemImage: "arrow.triangle.2.circlepath"
                ) {
                    Task { _ = await onSynchronize() }
                }
                .disabled(!isAuthorized || !model.canSynchronize)
                .accessibilityHint(
                    "Applique uniquement la prévisualisation affichée"
                )
                .help(synchronizationHelp)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private func browserRelationship(
        _ preview: SynchronizationPreviewPresentation
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Spacing.s) {
                browserSummary(preview.source, role: "Source")
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                browserSummary(preview.target, role: "Cible")
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                browserSummary(preview.source, role: "Source")
                Image(systemName: "arrow.down")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                browserSummary(preview.target, role: "Cible")
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
            Text(
                "\(summary.bookmarkCount) favoris · \(summary.folderCount) dossiers"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var synchronizationHelp: String {
        if !isAuthorized {
            return "Autorisez Safari et Chrome avant de synchroniser"
        }
        if model.isSynchronizing {
            return "Une synchronisation est déjà en cours"
        }
        return DocumentationText.value("tooltip.synchronize")
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
            label: "Créations",
            systemImage: "plus"
        )
    }

    private var deletion: some View {
        statistic(
            value: preview.deletionCount,
            label: "Suppressions",
            systemImage: "trash"
        )
    }

    private var move: some View {
        statistic(
            value: preview.moveCount,
            label: "Déplacements",
            systemImage: "arrow.right"
        )
    }

    private var rename: some View {
        statistic(
            value: preview.renameCount,
            label: "Renommages",
            systemImage: "pencil"
        )
    }

    private var update: some View {
        statistic(
            value: preview.urlModificationCount,
            label: "Mises à jour",
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
