//
//  SynchronizationDirectionScreen.swift
//  BookmarkBridge
//

import SwiftUI

/// Entry point for synchronization. Reading remains coordinated by the app;
/// this view only routes the user to the selected direction.
struct SynchronizationDirectionScreen: View {
    let model: SynchronizationViewModel
    let isAuthorized: Bool
    let onSelectDirection:
        @MainActor (ProductionSynchronizationDirection) async -> Void
    let onReloadDirection:
        @MainActor (ProductionSynchronizationDirection) async -> Void
    let onSynchronize: @MainActor () async -> Bool
    let onReportError: @MainActor () async -> Void

    private enum Phase {
        case selection
        case direction
        case preview
    }

    @State private var phase: Phase = .selection
    @State private var isLoadingPreview = false

    var body: some View {
        switch phase {
        case .selection:
            SynchronizationSelectionScreen(
                model: model.selection,
                onContinue: { phase = .direction }
            )
        case .direction:
            directionChoice
        case .preview:
            if let direction = model.directionNavigation.selectedDirection {
                previewScreen(direction: direction.previewDirection)
            } else {
                directionChoice
            }
        }
    }

    private func previewScreen(
        direction: ProductionSynchronizationDirection
    ) -> some View {
        SynchronizationPreviewScreen(
                model: model,
                isAuthorized: isAuthorized,
                onReload: {
                    await onReloadDirection(direction)
                },
                onSynchronize: onSynchronize,
                onReportError: onReportError,
                onBack: { phase = .direction },
                allowsSynchronization: true
            )
    }

    private var directionChoice: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                ScreenHeader(
                    DocumentationText.value("synchronization.title"),
                    subtitle: DocumentationText.value(
                        "synchronization.direction.subtitle"
                    )
                )

                PrimaryActionRow {
                    PrimaryActionButton(
                        DocumentationText.value("selection.preview"),
                        systemImage: "eye"
                    ) {
                        loadPreview()
                    }
                    .disabled(
                        model.directionNavigation.selectedDirection == nil
                            || isLoadingPreview
                    )
                }

                SynchronizationSummaryCard(
                    DocumentationText.value("synchronization.direction.title")
                ) {
                    VStack(spacing: Theme.Spacing.m) {
                        directionButton(.safariToChrome)
                        directionButton(.chromeToSafari)
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
        .navigationTitle(DocumentationText.value("synchronization.title"))
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    phase = .selection
                } label: {
                    Label(
                        DocumentationText.value("action.back"),
                        systemImage: "chevron.left"
                    )
                }
                .disabled(isLoadingPreview)
            }

            ToolbarItem(placement: .primaryAction) {
                ContextualHelpButton(pageID: .synchronization)
            }
        }
    }

    private func directionButton(
        _ direction: SynchronizationDirectionOption
    ) -> some View {
        Button {
            model.directionNavigation.select(direction)
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                BrowserLogo(
                    browser: direction == .safariToChrome
                        ? .safari
                        : .chrome,
                    size: 32
                )
                    .frame(width: Theme.Size.minimumInteractive)

                Text(direction.title)
                    .font(.headline)

                Spacer()

                Image(
                    systemName:
                        model.directionNavigation.selectedDirection == direction
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .foregroundStyle(
                    model.directionNavigation.selectedDirection == direction
                        ? Color.accentColor
                        : Color.secondary
                )
            }
            .padding(Theme.Spacing.m)
            .contentShape(Rectangle())
            .background(
                model.directionNavigation.selectedDirection == direction
                    ? Color.accentColor.opacity(0.08)
                    : Color.clear,
                in: RoundedRectangle(
                    cornerRadius: Theme.Radius.card,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(direction.title)
    }

    private func loadPreview() {
        guard let direction = model.directionNavigation.selectedDirection,
              !isLoadingPreview else { return }
        isLoadingPreview = true
        Task {
            await onSelectDirection(direction.previewDirection)
            isLoadingPreview = false
            phase = .preview
        }
    }

}
