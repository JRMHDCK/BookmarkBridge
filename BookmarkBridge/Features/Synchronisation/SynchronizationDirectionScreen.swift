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

    @State private var navigation = SynchronizationDirectionNavigation()

    var body: some View {
        switch navigation.selectedDirection {
        case nil:
            directionChoice
        case .safariToChrome:
            SynchronizationPreviewScreen(
                model: model,
                isAuthorized: isAuthorized,
                onReload: {
                    await onReloadDirection(.safariToChrome)
                },
                onSynchronize: onSynchronize,
                onBack: { navigation.goBack() },
                allowsSynchronization: true
            )
        case .chromeToSafari:
            SynchronizationPreviewScreen(
                model: model,
                isAuthorized: isAuthorized,
                onReload: {
                    await onReloadDirection(.chromeToSafari)
                },
                onSynchronize: onSynchronize,
                onBack: { navigation.goBack() },
                allowsSynchronization: true
            )
        }
    }

    private var directionChoice: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                ScreenHeader(
                    "Synchronisation",
                    subtitle: "Choisissez le sens de la synchronisation."
                )

                SynchronizationSummaryCard("Direction") {
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
        .navigationTitle("Synchronisation")
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
            navigation.select(direction)
            Task {
                await onSelectDirection(direction.previewDirection)
            }
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: direction == .safariToChrome
                    ? "safari"
                    : "globe")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
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
