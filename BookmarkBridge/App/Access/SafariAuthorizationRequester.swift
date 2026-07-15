//
//  SafariAuthorizationRequester.swift
//  BookmarkBridge
//

#if os(macOS)
import Foundation

/// Adapts `SafariAccessCoordinator` to the dashboard's UI-agnostic
/// `BookmarkAuthorizationRequesting` abstraction.
///
/// It maps the coordinator's outcome to the ViewModel's contract: a granted
/// authorization returns `true`, a user cancellation returns `false` (no error),
/// and any genuine failure (wrong file, bookmark/persistence failure) propagates.
struct SafariAuthorizationRequester: BookmarkAuthorizationRequesting {
    let coordinator: SafariAccessCoordinator

    func requestAuthorization(for browser: Browser) async throws -> Bool {
        guard browser == .safari else {
            throw BookmarkError.unsupportedBrowser(browser)
        }
        do {
            _ = try await coordinator.authorize()
            return true
        } catch SafariAccessError.cancelled {
            return false
        }
    }
}
#endif
