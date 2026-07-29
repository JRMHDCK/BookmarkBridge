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
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                SectionHeader(
                    "Synchronisation",
                    systemImage: "arrow.triangle.2.circlepath",
                    subtitle: "Prévisualisez les changements avant toute écriture."
                )
                SynchronizationSummaryCard {
                    executionStatus
                    previewContent
                }
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
            ToolbarItem {
                Button {
                    Task { await onReload() }
                } label: {
                    Label("Actualiser", systemImage: "arrow.clockwise")
                }
                .disabled(model.isSynchronizing)
                .accessibilityLabel(
                    "Actualiser la prévisualisation de la synchronisation"
                )
            }
        }
    }

    @ViewBuilder
    private var executionStatus: some View {
        switch model.executionState {
        case .idle, .completed:
            EmptyView()
        case .preparing:
            progressLabel("Préparation de la synchronisation…")
        case .writing:
            progressLabel("Synchronisation en cours…")
        case .validating:
            progressLabel("Validation de la synchronisation…")
        case .failed(let message):
            ErrorStateView(message: message, onRetry: nil)
        }
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
            .frame(minHeight: 220)
        case .loading:
            progressLabel("Calcul de la prévisualisation…")
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
            HStack(spacing: Theme.Spacing.s) {
                browserSummary(preview.source, role: "Source")
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                browserSummary(preview.target, role: "Cible")
            }

            if isEmpty {
                Label(
                    "Les navigateurs sont synchronisés",
                    systemImage: "checkmark.circle.fill"
                )
                .foregroundStyle(Theme.Palette.green)
            } else {
                Text(
                    "\(preview.totalOperationCount) changement\(preview.totalOperationCount == 1 ? "" : "s") détecté\(preview.totalOperationCount == 1 ? "" : "s")"
                )
                .font(.callout.weight(.medium))
            }

            HStack(alignment: .top, spacing: Theme.Spacing.s) {
                StatisticCard(
                    value: preview.creationCount,
                    label: "Créations",
                    prominent: false
                )
                StatisticCard(
                    value: preview.deletionCount,
                    label: "Suppressions",
                    prominent: false
                )
                StatisticCard(
                    value: preview.moveCount,
                    label: "Déplacements",
                    prominent: false
                )
                StatisticCard(
                    value: preview.renameCount,
                    label: "Renommages",
                    prominent: false
                )
                StatisticCard(
                    value: preview.urlModificationCount,
                    label: "URLs",
                    prominent: false
                )
            }

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

    private func progressLabel(_ title: String) -> some View {
        HStack(spacing: Theme.Spacing.s) {
            ProgressView().controlSize(.small)
            Text(title).foregroundStyle(.secondary)
        }
    }
}
