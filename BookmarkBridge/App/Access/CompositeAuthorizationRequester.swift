//
//  CompositeAuthorizationRequester.swift
//  BookmarkBridge
//

import Foundation

/// Routes an authorization request to the per-browser requester that handles it.
///
/// Lets the dashboard depend on a single `BookmarkAuthorizationRequesting` while
/// each browser keeps its own coordinator/authorizer (Safari file, Chrome folder).
@MainActor
struct CompositeAuthorizationRequester: BookmarkAuthorizationRequesting {
    private let requesters: [Browser: any BookmarkAuthorizationRequesting]

    init(_ requesters: [Browser: any BookmarkAuthorizationRequesting]) {
        self.requesters = requesters
    }

    func requestAuthorization(for browser: Browser) async throws -> Bool {
        guard let requester = requesters[browser] else {
            throw BookmarkError.unsupportedBrowser(browser)
        }
        return try await requester.requestAuthorization(for: browser)
    }
}
