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

    var title: String {
        switch self {
        case .safariToChrome:
            "Safari → Chrome"
        case .chromeToSafari:
            "Chrome → Safari"
        }
    }

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

    func select(_ direction: SynchronizationDirectionOption) {
        selectedDirection = direction
    }

    func goBack() {
        selectedDirection = nil
    }
}
