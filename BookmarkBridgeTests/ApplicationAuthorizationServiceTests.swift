//
//  ApplicationAuthorizationServiceTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("ApplicationAuthorizationService")
@MainActor
struct ApplicationAuthorizationServiceTests {
    private let safariBookmark = Data("safari".utf8)
    private let chromeBookmark = Data("chrome".utf8)
    private let safariURL = URL(
        fileURLWithPath: "/Users/tester/Library/Safari/Bookmarks.plist"
    )
    private let chromeURL = URL(
        fileURLWithPath:
            "/Users/tester/Library/Application Support/Google/Chrome",
        isDirectory: true
    )

    @Test("First launch reports both authorizations absent")
    func firstLaunch() async {
        let fixture = makeFixture()

        let state = await fixture.service.restoreAuthorizations()

        #expect(state.status == .absent)
        #expect(state.safari == .missing)
        #expect(state.chrome == .missing)
        #expect(fixture.requester.requestedBrowsers.isEmpty)
    }

    @Test("Restores two valid bookmarks without prompting")
    func restoresBookmarksWithoutPrompting() async {
        let fixture = makeFixture(
            safariStored: true,
            chromeStored: true
        )

        let state = await fixture.service.restoreAuthorizations()

        #expect(state.status == .complete)
        #expect(state.safari == .valid)
        #expect(state.chrome == .valid)
        #expect(fixture.requester.requestedBrowsers.isEmpty)
        #expect(fixture.resolver.resolvedData == [
            safariBookmark,
            chromeBookmark,
        ])
    }

    @Test("An invalid bookmark is reported independently")
    func invalidBookmark() async {
        let fixture = makeFixture(
            safariStored: true,
            resolverFailureData: [safariBookmark]
        )

        let state = await fixture.service.restoreAuthorizations()

        #expect(state.status == .invalidBookmark)
        #expect(state.safari == .invalidBookmark)
        #expect(state.chrome == .missing)
    }

    @Test("A valid Safari authorization is kept when Chrome is absent")
    func partialAuthorization() async {
        let fixture = makeFixture(safariStored: true)

        let state = await fixture.service.restoreAuthorizations()

        #expect(state.status == .partial)
        #expect(state.safari == .valid)
        #expect(state.chrome == .missing)
    }

    @Test("A new service restores bookmarks persisted by the previous session")
    func simulatedRestart() async {
        let store = InMemoryBookmarkStore()
        store.preset(safariBookmark, for: .safari)
        store.preset(chromeBookmark, for: .chrome)
        let first = makeFixture(store: store)
        let second = makeFixture(store: store)

        let firstState = await first.service.restoreAuthorizations()
        let secondState = await second.service.restoreAuthorizations()

        #expect(firstState == secondState)
        #expect(secondState.status == .complete)
        #expect(second.requester.requestedBrowsers.isEmpty)
    }

    @Test("Requesting only the missing Chrome access preserves Safari")
    func requestsOnlyMissingAuthorization() async {
        let store = InMemoryBookmarkStore()
        store.preset(safariBookmark, for: .safari)
        let fixture = makeFixture(store: store)
        fixture.requester.onRequest = { browser in
            if browser == .chrome {
                store.preset(self.chromeBookmark, for: .chrome)
            }
        }

        let state = await fixture.service.requestAuthorizationState(
            for: .chrome
        )

        #expect(fixture.requester.requestedBrowsers == [.chrome])
        #expect(state.status == .complete)
        #expect(state.safari == .valid)
        #expect(state.chrome == .valid)
    }

    @Test("Resolution failures do not erase the other valid bookmark")
    func resolutionError() async throws {
        let fixture = makeFixture(
            safariStored: true,
            chromeStored: true,
            resolverFailureData: [chromeBookmark]
        )

        let state = await fixture.service.restoreAuthorizations()

        #expect(state.safari == .valid)
        #expect(state.chrome == .invalidBookmark)
        #expect(state.status == .invalidBookmark)
        #expect(try fixture.store.loadBookmark(for: .safari) == safariBookmark)
        #expect(try fixture.store.loadBookmark(for: .chrome) == chromeBookmark)
    }

    @Test("An inaccessible resolved location is a typed access error")
    func inaccessibleLocation() async {
        let controller = AuthorizationFileController()
        controller.readable = false
        let fixture = makeFixture(
            safariStored: true,
            fileController: controller
        )

        let state = await fixture.service.restoreAuthorizations()

        #expect(
            state.safari == .accessError(.locationUnavailable)
        )
        #expect(state.status == .accessError)
    }

    @Test("A stale bookmark is refreshed and persisted")
    func refreshesStaleBookmark() async throws {
        let refreshed = Data("refreshed".utf8)
        let store = InMemoryBookmarkStore()
        store.preset(safariBookmark, for: .safari)
        let resolver = AuthorizationBookmarkResolver(
            resolutions: [
                safariBookmark: ResolvedBookmark(
                    url: safariURL,
                    isStale: true
                ),
            ]
        )
        let creator = StubBookmarkCreator(.success(refreshed))
        let fixture = makeFixture(
            store: store,
            resolver: resolver,
            creator: creator
        )

        let state = await fixture.service.restoreAuthorizations()

        #expect(state.safari == .valid)
        #expect(try store.loadBookmark(for: .safari) == refreshed)
        #expect(creator.requestedURLs == [safariURL])
    }

    @Test("The observable ViewModel exposes restored and requested states")
    func viewModelState() async {
        let service = AuthorizationServiceDouble(
            restored: ApplicationAuthorizationState(
                safari: .valid,
                chrome: .missing
            ),
            requested: ApplicationAuthorizationState(
                safari: .valid,
                chrome: .valid
            )
        )
        let viewModel = ApplicationAuthorizationViewModel(service: service)

        await viewModel.restore()
        #expect(viewModel.state.status == .partial)
        #expect(!viewModel.isLoading)

        await viewModel.authorize(.chrome)
        #expect(viewModel.state.status == .complete)
        #expect(service.requestedBrowsers == [.chrome])
        #expect(!viewModel.isLoading)
    }

    private func makeFixture(
        store: InMemoryBookmarkStore = InMemoryBookmarkStore(),
        safariStored: Bool = false,
        chromeStored: Bool = false,
        resolverFailureData: Set<Data> = [],
        resolver: AuthorizationBookmarkResolver? = nil,
        creator: StubBookmarkCreator = StubBookmarkCreator(
            .success(Data("refreshed".utf8))
        ),
        fileController: AuthorizationFileController =
            AuthorizationFileController()
    ) -> Fixture {
        if safariStored {
            store.preset(safariBookmark, for: .safari)
        }
        if chromeStored {
            store.preset(chromeBookmark, for: .chrome)
        }
        let resolver = resolver ?? AuthorizationBookmarkResolver(
            resolutions: [
                safariBookmark: ResolvedBookmark(
                    url: safariURL,
                    isStale: false
                ),
                chromeBookmark: ResolvedBookmark(
                    url: chromeURL,
                    isStale: false
                ),
            ],
            failureData: resolverFailureData
        )
        let requester = AuthorizationRequesterSpy()
        let service = ApplicationAuthorizationService(
            store: store,
            resolver: resolver,
            creator: creator,
            fileController: fileController,
            requester: requester
        )
        return Fixture(
            service: service,
            store: store,
            resolver: resolver,
            requester: requester
        )
    }

    private struct Fixture {
        let service: ApplicationAuthorizationService
        let store: InMemoryBookmarkStore
        let resolver: AuthorizationBookmarkResolver
        let requester: AuthorizationRequesterSpy
    }
}

private struct AuthorizationResolutionFailure: Error {}

private final class AuthorizationBookmarkResolver:
    SecurityScopedBookmarkResolving,
    @unchecked Sendable
{
    let resolutions: [Data: ResolvedBookmark]
    let failureData: Set<Data>
    private(set) var resolvedData: [Data] = []

    init(
        resolutions: [Data: ResolvedBookmark],
        failureData: Set<Data> = []
    ) {
        self.resolutions = resolutions
        self.failureData = failureData
    }

    func resolve(_ data: Data) throws -> ResolvedBookmark {
        resolvedData.append(data)
        guard !failureData.contains(data),
              let resolution = resolutions[data] else {
            throw AuthorizationResolutionFailure()
        }
        return resolution
    }
}

private final class AuthorizationFileController:
    SecurityScopedFileControlling,
    @unchecked Sendable
{
    var exists = true
    var readable = true
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func fileExists(at url: URL) -> Bool {
        exists
    }

    func isReadable(at url: URL) -> Bool {
        readable
    }

    func startAccessing(_ url: URL) -> Bool {
        startCount += 1
        return true
    }

    func stopAccessing(_ url: URL) {
        stopCount += 1
    }
}

@MainActor
private final class AuthorizationRequesterSpy:
    BookmarkAuthorizationRequesting
{
    var onRequest: ((Browser) -> Void)?
    var result = true
    private(set) var requestedBrowsers: [Browser] = []

    func requestAuthorization(for browser: Browser) async throws -> Bool {
        requestedBrowsers.append(browser)
        onRequest?(browser)
        return result
    }
}

@MainActor
private final class AuthorizationServiceDouble:
    ApplicationAuthorizationManaging
{
    let restored: ApplicationAuthorizationState
    let requested: ApplicationAuthorizationState
    private(set) var requestedBrowsers: [Browser] = []

    init(
        restored: ApplicationAuthorizationState,
        requested: ApplicationAuthorizationState
    ) {
        self.restored = restored
        self.requested = requested
    }

    func restoreAuthorizations() async -> ApplicationAuthorizationState {
        restored
    }

    func requestAuthorizationState(
        for browser: Browser
    ) async -> ApplicationAuthorizationState {
        requestedBrowsers.append(browser)
        return requested
    }
}
