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

    // MARK: - retry(_:)

    @Test("retry reloads only the targeted browser")
    func retryReloadsOnlyThatBrowser() async {
        let safariBox = AuthorizationBox()
        let chromeBox = AuthorizationBox()
        let viewModel = DashboardViewModel(readers: [
            GatedBookmarkReader(browser: .safari, box: safariBox, tree: .sample(for: .safari)),
            GatedBookmarkReader(browser: .chrome, box: chromeBox, tree: .sample(for: .chrome)),
        ])

        await viewModel.load()
        #expect(status(viewModel, .safari) == .authorizationRequired)
        #expect(status(viewModel, .chrome) == .authorizationRequired)

        // Access becomes available out-of-band for Safari only.
        safariBox.isAuthorized = true
        await viewModel.retry(.safari)

        guard case .loaded? = status(viewModel, .safari) else {
            Issue.record("expected Safari .loaded")
            return
        }
        #expect(status(viewModel, .chrome) == .authorizationRequired)   // untouched
    }

    @Test("retry never prompts; stays authorizationRequired when still unauthorized")
    func retryStaysAuthorizationRequired() async {
        let box = AuthorizationBox()
        let viewModel = DashboardViewModel(
            readers: [GatedBookmarkReader(browser: .safari, box: box, tree: .sample(for: .safari))]
        )

        await viewModel.load()
        await viewModel.retry(.safari)

        #expect(status(viewModel, .safari) == .authorizationRequired)
    }

    // MARK: - reloadAll()

    @Test("reloadAll reloads every browser")
    func reloadAllReloadsEveryBrowser() async {
        let viewModel = DashboardViewModel(readers: [
            InMemoryBookmarkReader(browser: .safari, tree: .sample(for: .safari)),
            InMemoryBookmarkReader(browser: .chrome, tree: .sample(for: .chrome)),
        ])

        await viewModel.reloadAll()

        #expect(viewModel.browsers.count == 2)
        for entry in viewModel.browsers {
            guard case .loaded = entry.status else {
                Issue.record("expected .loaded for \(entry.browser)")
                return
            }
        }
    }

    @Test("reloadAll never requests authorization")
    func reloadAllNeverPrompts() async {
        let box = AuthorizationBox()
        let requester = FakeAuthorizationRequester(box: box, outcome: .success(true))
        let viewModel = DashboardViewModel(
            readers: [GatedBookmarkReader(browser: .safari, box: box, tree: .sample(for: .safari))],
            authorizer: requester
        )

        await viewModel.reloadAll()

        #expect(status(viewModel, .safari) == .authorizationRequired)
        #expect(requester.requestCount == 0)
    }

    @Test("isLoading is false once loading has finished")
    func isLoadingFalseAfterLoad() async {
        let viewModel = DashboardViewModel(readers: [
            InMemoryBookmarkReader(browser: .safari, tree: .sample(for: .safari))
        ])

        await viewModel.load()

        #expect(viewModel.isLoading == false)
    }

    // MARK: - Error messages (simple, non-technical French)

    @Test("A decoding failure maps to a simple French message")
    func decodingFailureMessage() async {
        let viewModel = DashboardViewModel(readers: [
            FailingBookmarkReader(browser: .safari, error: .decodingFailed(.safari, reason: "boom"))
        ])

        await viewModel.load()

        #expect(status(viewModel, .safari) == .failed("Format du fichier illisible."))
    }

    @Test("A source-not-found failure maps to a simple French message")
    func sourceNotFoundMessage() async {
        let viewModel = DashboardViewModel(readers: [
            FailingBookmarkReader(browser: .safari, error: .sourceNotFound(.safari))
        ])

        await viewModel.load()

        #expect(status(viewModel, .safari) == .failed("Fichier des favoris introuvable."))
    }

    @Test("A non-domain error maps to the generic message")
    func genericErrorMessage() async {
        struct Boom: Error {}
        let box = AuthorizationBox()
        let viewModel = DashboardViewModel(
            readers: [GatedBookmarkReader(browser: .safari, box: box, tree: .sample(for: .safari))],
            authorizer: FakeAuthorizationRequester(box: box, outcome: .failure(Boom()))
        )

        await viewModel.load()
        await viewModel.authorize(.safari)

        #expect(status(viewModel, .safari) == .failed("Une erreur est survenue."))
    }
}
