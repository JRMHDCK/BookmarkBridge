//
//  SynchronizationDirectionNavigation.swift
//  BookmarkBridge
//

import Observation

/// User-facing synchronization directions. Execution support remains a
/// separate concern owned by the synchronization destination.
nonisolated enum SynchronizationDirectionOption:
    String,
    CaseIterable,
    Hashable,
    Identifiable,
    Sendable
{
    case safariToChrome
    case chromeToSafari

    var id: Self { self }

    var titleKey: String {
        switch self {
        case .safariToChrome:
            "synchronization.direction.safariToChrome"
        case .chromeToSafari:
            "synchronization.direction.chromeToSafari"
        }
    }

    @MainActor
    var title: String { DocumentationText.value(titleKey) }

    var previewDirection: ProductionSynchronizationDirection {
        switch self {
        case .safariToChrome:
            .safariToChrome
        case .chromeToSafari:
            .chromeToSafari
        }
    }
}

/// Presentation-only navigation state for the synchronization feature.
@MainActor
@Observable
final class SynchronizationDirectionNavigation {
    private(set) var selectedDirection: SynchronizationDirectionOption?
    private let preferencesStore: any SynchronizationPreferencesStoring

    init(
        preferencesStore: any SynchronizationPreferencesStoring =
            InMemorySynchronizationPreferencesStore()
    ) {
        self.preferencesStore = preferencesStore
        selectedDirection = SynchronizationDirectionOption(
            rawValue: preferencesStore.load().selectedDirectionRawValue ?? ""
        )
    }

    func select(_ direction: SynchronizationDirectionOption) {
        selectedDirection = direction
        var preferences = preferencesStore.load()
        preferences.selectedDirectionRawValue = direction.rawValue
        preferencesStore.save(preferences)
    }

    func goBack() {
        selectedDirection = nil
    }
}
