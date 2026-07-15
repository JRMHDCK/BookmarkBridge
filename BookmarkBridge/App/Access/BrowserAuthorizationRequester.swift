//
//  BrowserAuthorizationRequester.swift
//  BookmarkBridge
//

#if os(macOS)
import Foundation

/// Adapts a `BrowserAccessCoordinator` to the dashboard's UI-agnostic
/// `BookmarkAuthorizationRequesting` abstraction, for one browser.
///
/// It maps the coordinator's outcome to the ViewModel's contract: a granted
/// authorization returns `true`, a user cancellation returns `false` (no error),
/// and any genuine failure (wrong selection, bookmark/persistence failure)
/// propagates.
struct BrowserAuthorizationRequester: BookmarkAuthorizationRequesting {
    let browser: Browser
    let coordinator: BrowserAccessCoordinator

    func requestAuthorization(for browser: Browser) async throws -> Bool {
        guard browser == self.browser else {
            throw BookmarkError.unsupportedBrowser(browser)
        }
        do {
            _ = try await coordinator.authorize()
            return true
        } catch AccessError.cancelled {
            return false
        }
    }
}
#endif
