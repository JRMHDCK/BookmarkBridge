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

    private func id(_ browser: Browser, _ profile: String? = nil) -> BookmarkSourceID {
        BookmarkSourceID(browser: browser, profile: profile)
    }

    private func status(_ viewModel: DashboardViewModel, _ sourceID: BookmarkSourceID) -> DashboardViewModel.Status? {
        viewModel.sources.first { $0.id == sourceID }?.status
    }

    private func chromeReader(profile: String, name: String) -> InMemoryBookmarkReader {
        InMemoryBookmarkReader(
            source: BookmarkSource(browser: .chrome, profile: profile, displayName: name),
            tree: .sample(for: .chrome)
        )
    }

    // MARK: - Loading

    @Test("Starts with no source entries before loading")
    func startsEmpty() {
        let viewModel = DashboardViewModel(providers: [])
        #expect(viewModel.sources.isEmpty)
    }

    @Test("Loads Safari's single source")
    func loadsSafari() async {
        let viewModel = DashboardViewModel(providers: [
            StubSourceProvider(browser: .safari, readers: [
                InMemoryBookmarkReader(browser: .safari, tree: .sample(for: .safari))
            ])
        ])

        await viewModel.load()

        #expect(status(viewModel, id(.safari)) == .loaded(BrowserBookmarkSummary(tree: .sample(for: .safari))))
    }

    @Test("Loads one card per discovered Chrome profile")
    func loadsChromeProfiles() async {
        let viewModel = DashboardViewModel(providers: [
            StubSourceProvider(browser: .chrome, readers: [
                chromeReader(profile: "Default", name: "Chrome — Personnel"),
                chromeReader(profile: "Profile 1", name: "Chrome — Travail"),
            ])
        ])

        await viewModel.load()

        #expect(viewModel.sources.map(\.source.displayName) == ["Chrome — Personnel", "Chrome — Travail"])
        guard case .loaded? = status(viewModel, id(.chrome, "Default")),
              case .loaded? = status(viewModel, id(.chrome, "Profile 1")) else {
            Issue.record("expected both Chrome profiles loaded")
            return
        }
    }

    @Test("With no providers, there are no entries after loading")
    func loadsNothingWhenNoProviders() async {
        let viewModel = DashboardViewModel(providers: [])
        await viewModel.load()
        #expect(viewModel.sources.isEmpty)
    }

    // MARK: - Searchable sources

    @Test("Loaded sources are exposed as searchable (source + tree) pairs")
    func exposesSearchableSources() async {
        let viewModel = DashboardViewModel(providers: [
            StubSourceProvider(browser: .safari, readers: [
                InMemoryBookmarkReader(browser: .safari, tree: .sample(for: .safari))
            ])
        ])

        await viewModel.load()

        let searchable = viewModel.searchableSources
        #expect(searchable.count == 1)
        #expect(searchable.first?.source.id == id(.safari))
        #expect(searchable.first?.tree == .sample(for: .safari))
    }

    @Test("Sources requiring authorization are omitted from searchable sources")
    func omitsUnloadedSourcesFromSearch() async {
        let viewModel = DashboardViewModel(providers: [
            StubSourceProvider(browser: .chrome, error: .authorizationRequired(.chrome))
        ])

        await viewModel.load()

        #expect(viewModel.searchableSources.isEmpty)
    }

    // MARK: - Authorization required (browser level)

    @Test("A provider requiring authorization shows a browser-level card")
    func providerAuthorizationRequired() async {
        let viewModel = DashboardViewModel(providers: [
            StubSourceProvider(browser: .chrome, error: .authorizationRequired(.chrome))
        ])

        await viewModel.load()

        #expect(status(viewModel, id(.chrome)) == .authorizationRequired)
        #expect(viewModel.sources.first?.source.displayName == "Google Chrome")
    }

    @Test("A provider failure shows a browser-level failed card")
    func providerFailure() async {
        let viewModel = DashboardViewModel(providers: [
            StubSourceProvider(browser: .chrome, error: .sourceNotFound(.chrome))
        ])

        await viewModel.load()

        guard case .failed = status(viewModel, id(.chrome)) else {
            Issue.record("expected browser-level .failed")
            return
        }
    }

    // MARK: - Source-level failures

    @Test("A reader failure maps to a simple French message for that source")
    func sourceReadFailure() async {
        let viewModel = DashboardViewModel(providers: [
            StubSourceProvider(browser: .safari, readers: [
                FailingBookmarkReader(browser: .safari, error: .decodingFailed(.safari, reason: "boom"))
            ])
        ])

        await viewModel.load()

        #expect(
            status(viewModel, id(.safari)) == .failed(
                DocumentationText.value("error.fileUnreadable.short")
            )
        )
    }

    // MARK: - Authorization flow

    @Test("Authorizing discovers the browser's profiles")
    func authorizeDiscoversProfiles() async {
        let box = AuthorizationBox()
        let viewModel = DashboardViewModel(
            providers: [
                GatedSourceProvider(browser: .chrome, box: box, readers: [
                    chromeReader(profile: "Default", name: "Chrome — Personnel"),
                    chromeReader(profile: "Profile 1", name: "Chrome — Travail"),
                ])
            ],
            authorizer: FakeAuthorizationRequester(box: box, outcome: .success(true))
        )

        await viewModel.load()
        #expect(status(viewModel, id(.chrome)) == .authorizationRequired)   // browser-level

        await viewModel.authorize(id(.chrome))

        #expect(status(viewModel, id(.chrome)) == nil)                      // browser-level card gone
        guard case .loaded? = status(viewModel, id(.chrome, "Default")),
              case .loaded? = status(viewModel, id(.chrome, "Profile 1")) else {
            Issue.record("expected profiles loaded after authorization")
            return
        }
    }

    @Test("User cancellation returns silently to the browser-level prompt")
    func authorizeCancel() async {
        let box = AuthorizationBox()
        let viewModel = DashboardViewModel(
            providers: [GatedSourceProvider(browser: .chrome, box: box, readers: [])],
            authorizer: FakeAuthorizationRequester(box: box, outcome: .success(false))
        )

        await viewModel.load()
        await viewModel.authorize(id(.chrome))

        #expect(status(viewModel, id(.chrome)) == .authorizationRequired)
    }

    @Test("A genuine authorization failure surfaces as .failed")
    func authorizeFailure() async {
        let box = AuthorizationBox()
        let viewModel = DashboardViewModel(
            providers: [GatedSourceProvider(browser: .chrome, box: box, readers: [])],
            authorizer: FakeAuthorizationRequester(box: box, outcome: .failure(Boom()))
        )

        await viewModel.load()
        await viewModel.authorize(id(.chrome))

        #expect(
            status(viewModel, id(.chrome)) == .failed(
                DocumentationText.value("error.generic.short")
            )
        )
    }

    // MARK: - retry & reloadAll

    @Test("Retry rediscovers a browser-level card")
    func retryRediscovers() async {
        let box = AuthorizationBox()
        let viewModel = DashboardViewModel(providers: [
            GatedSourceProvider(browser: .chrome, box: box, readers: [
                chromeReader(profile: "Default", name: "Chrome — Personnel")
            ])
        ])

        await viewModel.load()
        #expect(status(viewModel, id(.chrome)) == .authorizationRequired)

        // Access becomes available out-of-band.
        box.isAuthorized = true
        await viewModel.retry(id(.chrome))

        guard case .loaded? = status(viewModel, id(.chrome, "Default")) else {
            Issue.record("expected profile loaded after retry")
            return
        }
    }

    @Test("reloadAll never requests authorization")
    func reloadAllNeverPrompts() async {
        let box = AuthorizationBox()
        let requester = FakeAuthorizationRequester(box: box, outcome: .success(true))
        let viewModel = DashboardViewModel(
            providers: [GatedSourceProvider(browser: .chrome, box: box, readers: [])],
            authorizer: requester
        )

        await viewModel.reloadAll()

        #expect(status(viewModel, id(.chrome)) == .authorizationRequired)
        #expect(requester.requestCount == 0)
    }

    @Test("isLoading is false once loading has finished")
    func isLoadingFalseAfterLoad() async {
        let viewModel = DashboardViewModel(providers: [
            StubSourceProvider(browser: .safari, readers: [
                InMemoryBookmarkReader(browser: .safari, tree: .sample(for: .safari))
            ])
        ])

        await viewModel.load()

        #expect(viewModel.isLoading == false)
    }

    // MARK: - Decoded tree cache (for the explorer)

    @Test("Keeps the decoded tree for a loaded source")
    func keepsTreeAfterLoad() async {
        let tree = BookmarkTree.sample(for: .safari)
        let viewModel = DashboardViewModel(providers: [
            StubSourceProvider(browser: .safari, readers: [
                InMemoryBookmarkReader(browser: .safari, tree: tree)
            ])
        ])

        await viewModel.load()

        #expect(viewModel.tree(for: id(.safari)) == tree)
    }

    @Test("No tree is returned before loading or for an unknown source")
    func noTreeWhenAbsent() async {
        let viewModel = DashboardViewModel(providers: [
            StubSourceProvider(browser: .safari, readers: [
                InMemoryBookmarkReader(browser: .safari, tree: .sample(for: .safari))
            ])
        ])

        #expect(viewModel.tree(for: id(.safari)) == nil)   // before load

        await viewModel.load()

        #expect(viewModel.tree(for: id(.chrome)) == nil)   // unknown source
    }

    @Test("No tree is kept when the source fails to load")
    func noTreeWhenFailed() async {
        let viewModel = DashboardViewModel(providers: [
            StubSourceProvider(browser: .safari, readers: [
                FailingBookmarkReader(browser: .safari, error: .sourceNotFound(.safari))
            ])
        ])

        await viewModel.load()

        #expect(viewModel.tree(for: id(.safari)) == nil)
    }

    @Test("Keeps a distinct tree per Chrome profile")
    func keepsTreePerProfile() async {
        let treeA = BookmarkTree(
            browser: .chrome,
            roots: [BookmarkFolder(id: BookmarkID("a"), title: "A")],
            capturedAt: .distantPast
        )
        let treeB = BookmarkTree(
            browser: .chrome,
            roots: [BookmarkFolder(id: BookmarkID("b"), title: "B")],
            capturedAt: .distantPast
        )
        let viewModel = DashboardViewModel(providers: [
            StubSourceProvider(browser: .chrome, readers: [
                InMemoryBookmarkReader(
                    source: BookmarkSource(browser: .chrome, profile: "Default", displayName: "Chrome — Perso"),
                    tree: treeA
                ),
                InMemoryBookmarkReader(
                    source: BookmarkSource(browser: .chrome, profile: "Profile 1", displayName: "Chrome — Pro"),
                    tree: treeB
                ),
            ])
        ])

        await viewModel.load()

        #expect(viewModel.tree(for: id(.chrome, "Default")) == treeA)
        #expect(viewModel.tree(for: id(.chrome, "Profile 1")) == treeB)
    }

    @Test("Drops the tree when a reload requires re-authorization")
    func dropsTreeOnReauthorization() async {
        let box = AuthorizationBox(isAuthorized: true)
        let viewModel = DashboardViewModel(providers: [
            GatedSourceProvider(browser: .chrome, box: box, readers: [
                InMemoryBookmarkReader(
                    source: BookmarkSource(browser: .chrome, profile: "Default", displayName: "Chrome — Perso"),
                    tree: .sample(for: .chrome)
                )
            ])
        ])

        await viewModel.load()
        #expect(viewModel.tree(for: id(.chrome, "Default")) != nil)

        // Access revoked; a reload now yields a browser-level authorizationRequired card.
        box.isAuthorized = false
        await viewModel.reloadAll()

        #expect(viewModel.tree(for: id(.chrome, "Default")) == nil)
        #expect(status(viewModel, id(.chrome)) == .authorizationRequired)
    }
}
