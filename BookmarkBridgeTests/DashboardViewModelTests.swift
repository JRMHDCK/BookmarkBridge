//
//  DashboardViewModelTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("DashboardViewModel")
@MainActor
struct DashboardViewModelTests {

    private struct Boom: Error {}

    private func status(_ viewModel: DashboardViewModel, _ browser: Browser) -> DashboardViewModel.Status? {
        viewModel.browsers.first { $0.browser == browser }?.status
    }

    // MARK: - Loading

    @Test("Starts with no browser entries before loading")
    func startsEmpty() {
        let viewModel = DashboardViewModel(readers: [])
        #expect(viewModel.browsers.isEmpty)
    }

    @Test("Loads one entry per reader with correct counts")
    func loadsSummaries() async {
        let viewModel = DashboardViewModel(readers: [
            InMemoryBookmarkReader(browser: .safari, tree: .sample(for: .safari)),
            InMemoryBookmarkReader(browser: .chrome, tree: .sample(for: .chrome)),
        ])

        await viewModel.load()

        #expect(viewModel.browsers.map(\.browser) == [.safari, .chrome])
        #expect(status(viewModel, .safari) == .loaded(BrowserBookmarkSummary(tree: .sample(for: .safari))))
        #expect(status(viewModel, .chrome) == .loaded(BrowserBookmarkSummary(tree: .sample(for: .chrome))))
    }

    @Test("With no readers, there are no entries after loading")
    func loadsNothingWhenNoReaders() async {
        let viewModel = DashboardViewModel(readers: [])
        await viewModel.load()
        #expect(viewModel.browsers.isEmpty)
    }

    @Test("A non-authorization failure is surfaced as .failed for that browser")
    func surfacesFailure() async {
        let viewModel = DashboardViewModel(readers: [
            FailingBookmarkReader(browser: .safari, error: .sourceNotFound(.safari))
        ])

        await viewModel.load()

        guard case .failed = status(viewModel, .safari) else {
            Issue.record("expected .failed, got \(String(describing: status(viewModel, .safari)))")
            return
        }
    }

    @Test("An authorizationRequired error maps to the .authorizationRequired status")
    func detectsAuthorizationRequired() async {
        let viewModel = DashboardViewModel(readers: [
            FailingBookmarkReader(browser: .safari, error: .authorizationRequired(.safari))
        ])

        await viewModel.load()

        #expect(status(viewModel, .safari) == .authorizationRequired)
    }

    // MARK: - Authorization

    @Test("Authorizing on success reloads the browser to .loaded")
    func authorizeReloadsOnSuccess() async {
        let box = AuthorizationBox()
        let viewModel = DashboardViewModel(
            readers: [GatedBookmarkReader(browser: .safari, box: box, tree: .sample(for: .safari))],
            authorizer: FakeAuthorizationRequester(box: box, outcome: .success(true))
        )

        await viewModel.load()
        #expect(status(viewModel, .safari) == .authorizationRequired)

        await viewModel.authorize(.safari)

        guard case .loaded(let summary)? = status(viewModel, .safari) else {
            Issue.record("expected .loaded, got \(String(describing: status(viewModel, .safari)))")
            return
        }
        #expect(summary.bookmarkCount == 3)
    }

    @Test("User cancellation returns silently to the authorization prompt")
    func authorizeReturnsToPromptOnCancel() async {
        let box = AuthorizationBox()
        let viewModel = DashboardViewModel(
            readers: [GatedBookmarkReader(browser: .safari, box: box, tree: .sample(for: .safari))],
            authorizer: FakeAuthorizationRequester(box: box, outcome: .success(false))
        )

        await viewModel.load()
        await viewModel.authorize(.safari)

        #expect(status(viewModel, .safari) == .authorizationRequired)
    }

    @Test("A genuine authorization failure surfaces as .failed")
    func authorizeFailsOnError() async {
        let box = AuthorizationBox()
        let viewModel = DashboardViewModel(
            readers: [GatedBookmarkReader(browser: .safari, box: box, tree: .sample(for: .safari))],
            authorizer: FakeAuthorizationRequester(box: box, outcome: .failure(Boom()))
        )

        await viewModel.load()
        await viewModel.authorize(.safari)

        guard case .failed = status(viewModel, .safari) else {
            Issue.record("expected .failed, got \(String(describing: status(viewModel, .safari)))")
            return
        }
    }

    @Test("Without an authorizer, authorize() is a no-op")
    func authorizeNoopWithoutAuthorizer() async {
        let box = AuthorizationBox()
        let viewModel = DashboardViewModel(
            readers: [GatedBookmarkReader(browser: .safari, box: box, tree: .sample(for: .safari))]
        )

        await viewModel.load()
        await viewModel.authorize(.safari)

        #expect(status(viewModel, .safari) == .authorizationRequired)
    }
}
