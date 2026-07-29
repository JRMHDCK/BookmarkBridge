//
//  ApplicationAuthorizationManaging.swift
//  BookmarkBridge
//

import Foundation
import Observation

/// The independently validated authorization state for one browser.
nonisolated enum BrowserAuthorizationState: Equatable, Sendable {
    case missing
    case valid
    case invalidBookmark
    case accessError(AuthorizationAccessError)
}

/// Stable, presentation-safe categories for failures detected while restoring
/// or refreshing an authorization. No system error or file path crosses into
/// the view layer.
nonisolated enum AuthorizationAccessError: Equatable, Sendable {
    case storageUnavailable
    case locationUnavailable
    case bookmarkRefreshFailed
    case authorizationFailed
}

/// Aggregate states displayed by the dashboard.
nonisolated enum ApplicationAuthorizationStatus: Equatable, Sendable {
    case absent
    case partial
    case complete
    case invalidBookmark
    case accessError
}

/// A snapshot of both browser authorizations.
nonisolated struct ApplicationAuthorizationState: Equatable, Sendable {
    let safari: BrowserAuthorizationState
    let chrome: BrowserAuthorizationState

    init(
        safari: BrowserAuthorizationState,
        chrome: BrowserAuthorizationState
    ) {
        self.safari = safari
        self.chrome = chrome
    }

    static let absent = ApplicationAuthorizationState(
        safari: .missing,
        chrome: .missing
    )

    var status: ApplicationAuthorizationStatus {
        let states = [safari, chrome]
        if states.contains(where: { state in
            if case .accessError = state {
                return true
            }
            return false
        }) {
            return .accessError
        }
        if states.contains(.invalidBookmark) {
            return .invalidBookmark
        }
        if states.allSatisfy({ $0 == .valid }) {
            return .complete
        }
        if states.allSatisfy({ $0 == .missing }) {
            return .absent
        }
        return .partial
    }

    func state(for browser: Browser) -> BrowserAuthorizationState {
        switch browser {
        case .safari: safari
        case .chrome: chrome
        }
    }
}

/// Application-layer authorization operations consumed by the dashboard.
///
/// Restoration is non-interactive. Only `requestAuthorization(for:)` may
/// present the native picker through its injected production implementation.
@MainActor
protocol ApplicationAuthorizationManaging: Sendable {
    func restoreAuthorizations() async -> ApplicationAuthorizationState
    func requestAuthorizationState(
        for browser: Browser
    ) async -> ApplicationAuthorizationState
}

/// Observable presentation state for the authorization card.
@MainActor
@Observable
final class ApplicationAuthorizationViewModel {
    private(set) var state = ApplicationAuthorizationState.absent
    private(set) var isLoading = false

    private let service: any ApplicationAuthorizationManaging

    init(service: any ApplicationAuthorizationManaging) {
        self.service = service
    }

    func restore() async {
        isLoading = true
        state = await service.restoreAuthorizations()
        isLoading = false
    }

    func authorize(_ browser: Browser) async {
        isLoading = true
        state = await service.requestAuthorizationState(for: browser)
        isLoading = false
    }
}
