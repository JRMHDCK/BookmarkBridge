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

    @State private var showsPreview = false

    var body: some View {
        switch model.directionNavigation.selectedDirection {
        case nil:
            directionChoice
        case .some(let direction) where !showsPreview:
            SynchronizationSelectionScreen(
                model: model.selection,
                direction: direction,
                onContinue: {
                    await onSelectDirection(direction.previewDirection)
                    showsPreview = true
                },
                onBack: { model.directionNavigation.goBack() }
            )
        case .safariToChrome:
            previewScreen(direction: .safariToChrome)
        case .chromeToSafari:
            previewScreen(direction: .chromeToSafari)
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
                onBack: { showsPreview = false },
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

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(Theme.Spacing.m)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(direction.title)
    }

}
