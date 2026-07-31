//
//  BookmarkAccessTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("Bookmark access management")
@MainActor
struct BookmarkAccessTests {
    private let safariBookmark = Data("safari-access".utf8)
    private let chromeBookmark = Data("chrome-access".utf8)

    @Test("Safari detection uses the supplied current-user home directory")
    func detectsSafariPathWithoutHardcodedUser() async {
        let home = URL(fileURLWithPath: "/Users/dynamic-user", isDirectory: true)
        let service = makeService(homeDirectory: home)

        let snapshot = await service.inspectAccess()

        #expect(
            snapshot.safari.detectedURL.path
                == "/Users/dynamic-user/Library/Safari/Bookmarks.plist"
        )
        #expect(snapshot.safari.authorizedURL == nil)
        #expect(snapshot.safari.status == .authorizationMissing)
    }

    @Test("Safari detection escapes the application sandbox home directory")
    func detectsSafariPathFromSandboxHome() async {
        let sandboxHome = URL(
            fileURLWithPath: "/Users/dynamic-user/Library/Containers/fr.jerome.BookmarkBridge/Data",
            isDirectory: true
        )
        let service = makeService(homeDirectory: sandboxHome)

        let snapshot = await service.inspectAccess()

        #expect(
            snapshot.safari.detectedURL.path
                == "/Users/dynamic-user/Library/Safari/Bookmarks.plist"
        )
    }

    @Test("A resolved Safari bookmark exposes its authorized path and status")
    func inspectsAuthorizedSafariPath() async {
        let store = InMemoryBookmarkStore()
        store.preset(safariBookmark, for: .safari)
        let safariURL = URL(
            fileURLWithPath: "/Users/tester/Library/Safari/Bookmarks.plist"
        )
        let resolver = StubBookmarkResolver(
            .success(ResolvedBookmark(url: safariURL, isStale: false))
        )
        let service = makeService(store: store, resolver: resolver)

        let snapshot = await service.inspectAccess()
        let tested = await service.testAccess(
            for: .safari,
            chromeProfileDirectory: nil
        )

        #expect(snapshot.safari.authorizedURL == safariURL)
        #expect(snapshot.safari.status == .ok)
        #expect(tested == .ok)
    }

    @Test("An unreadable authorized Safari file is reported as invalid")
    func reportsInvalidSafariAuthorization() async {
        let store = InMemoryBookmarkStore()
        store.preset(safariBookmark, for: .safari)
        let safariURL = URL(
            fileURLWithPath: "/Users/tester/Library/Safari/Bookmarks.plist"
        )
        let resolver = StubBookmarkResolver(
            .success(ResolvedBookmark(url: safariURL, isStale: false))
        )
        let service = makeService(
            store: store,
            resolver: resolver,
            fileController: BookmarkAccessFileController(readable: false)
        )

        let snapshot = await service.inspectAccess()

        #expect(snapshot.safari.status == .authorizationInvalid)
    }

    @Test("Chrome profiles use Local State names and their storage paths")
    func discoversChromeProfilesAndNames() async throws {
        let store = InMemoryBookmarkStore()
        store.preset(chromeBookmark, for: .chrome)
        let chromeURL = URL(
            fileURLWithPath: "/Users/tester/Library/Application Support/Google/Chrome",
            isDirectory: true
        )
        let defaultBookmarks = chromeURL
            .appendingPathComponent("Default", isDirectory: true)
            .appendingPathComponent("Bookmarks")
        let profileBookmarks = chromeURL
            .appendingPathComponent("Profile 1", isDirectory: true)
            .appendingPathComponent("Bookmarks")
        let locator = BookmarkAccessProfileLocator(
            profiles: [
                ChromeProfileLocation(
                    profileDirectoryName: "Default",
                    storage: .bookmarks(defaultBookmarks)
                ),
                ChromeProfileLocation(
                    profileDirectoryName: "Profile 1",
                    storage: .bookmarks(profileBookmarks)
                ),
            ]
        )
        let localState = try #require(
            """
            {"profile":{"info_cache":{"Default":{"name":"Personnel"},"Profile 1":{"name":"Travail"}}}}
            """.data(using: .utf8)
        )
        let resolver = StubBookmarkResolver(
            .success(ResolvedBookmark(url: chromeURL, isStale: false))
        )
        let service = makeService(
            store: store,
            resolver: resolver,
            profileLocator: locator,
            readData: { url in
                if url.lastPathComponent == "Local State" {
                    return localState
                }
                return Data("bookmarks".utf8)
            }
        )

        let snapshot = await service.inspectAccess()

        #expect(snapshot.chrome.status == .ok)
        #expect(snapshot.chrome.authorizedDirectoryURL == chromeURL)
        #expect(snapshot.chrome.profiles.map(\.profileName) == ["Personnel", "Travail"])
        #expect(snapshot.chrome.profiles.map(\.directoryName) == ["Default", "Profile 1"])
        #expect(snapshot.chrome.profiles.map(\.bookmarksURL) == [defaultBookmarks, profileBookmarks])
    }

    @Test("The selected Chrome profile is restored and persisted immediately")
    func restoresAndPersistsChromeSelection() async {
        let profiles = [
            ChromeProfileAccess(
                directoryName: "Default",
                profileName: "Personnel",
                bookmarksURL: URL(fileURLWithPath: "/Chrome/Default/Bookmarks")
            ),
            ChromeProfileAccess(
                directoryName: "Profile 1",
                profileName: "Travail",
                bookmarksURL: URL(fileURLWithPath: "/Chrome/Profile 1/Bookmarks")
            ),
        ]
        let service = BookmarkAccessServiceDouble(
            snapshot: snapshot(chromeProfiles: profiles)
        )
        let selection = ChromeProfileSelectionStoreDouble(selected: "Profile 1")
        let viewModel = BookmarkAccessViewModel(
            service: service,
            selectionStore: selection
        )

        await viewModel.load()
        #expect(viewModel.selectedChromeProfile?.profileName == "Travail")

        viewModel.selectChromeProfile("Default")
        #expect(viewModel.selectedChromeProfileDirectory == "Default")
        #expect(selection.savedDirectories == ["Default"])
    }

    @Test("Re-select delegates to the existing authorization requester")
    func reselectUsesExistingAuthorizationFlow() async throws {
        let requester = BookmarkAccessRequesterSpy()
        let service = makeService(requester: requester)

        let granted = try await service.reauthorize(.chrome)

        #expect(granted)
        #expect(requester.requestedBrowsers == [.chrome])
    }

    private func makeService(
        store: InMemoryBookmarkStore = InMemoryBookmarkStore(),
        resolver: any SecurityScopedBookmarkResolving = StubBookmarkResolver(
            .failure(BookmarkAccessTestError.resolution)
        ),
        requester: any BookmarkAuthorizationRequesting = BookmarkAccessRequesterSpy(),
        profileLocator: any ChromeProfileLocating = BookmarkAccessProfileLocator(),
        fileController: any SecurityScopedFileControlling =
            BookmarkAccessFileController(),
        homeDirectory: URL = URL(fileURLWithPath: "/Users/tester", isDirectory: true),
        readData: @escaping @Sendable (URL) throws -> Data = { _ in Data() }
    ) -> BookmarkAccessService {
        BookmarkAccessService(
            store: store,
            resolver: resolver,
            fileController: fileController,
            requester: requester,
            profileLocator: profileLocator,
            homeDirectory: homeDirectory,
            readData: readData
        )
    }

    private func snapshot(
        chromeProfiles: [ChromeProfileAccess]
    ) -> BookmarkAccessSnapshot {
        BookmarkAccessSnapshot(
            safari: SafariBookmarkAccess(
                detectedURL: URL(fileURLWithPath: "/Safari/Bookmarks.plist"),
                authorizedURL: nil,
                status: .authorizationMissing
            ),
            chrome: ChromeBookmarkAccess(
                authorizedDirectoryURL: URL(fileURLWithPath: "/Chrome"),
                profiles: chromeProfiles,
                status: .ok
            )
        )
    }
}

private enum BookmarkAccessTestError: Error {
    case resolution
}

private struct BookmarkAccessProfileLocator: ChromeProfileLocating {
    let profilesToReturn: [ChromeProfileLocation]

    init(profiles: [ChromeProfileLocation] = []) {
        profilesToReturn = profiles
    }

    func defaultChromeDirectory() -> URL {
        URL(fileURLWithPath: "/Chrome", isDirectory: true)
    }

    func localStateURL(in chromeDirectory: URL) -> URL {
        chromeDirectory.appendingPathComponent("Local State")
    }

    func profiles(
        in chromeDirectory: URL
    ) throws -> [ChromeProfileLocation] {
        profilesToReturn
    }
}

private struct BookmarkAccessFileController: SecurityScopedFileControlling {
    let readable: Bool

    init(readable: Bool = true) {
        self.readable = readable
    }

    func fileExists(at url: URL) -> Bool { true }
    func isReadable(at url: URL) -> Bool { readable }
    func startAccessing(_ url: URL) -> Bool { true }
    func stopAccessing(_ url: URL) {}
}

@MainActor
private final class BookmarkAccessRequesterSpy: BookmarkAuthorizationRequesting {
    private(set) var requestedBrowsers: [Browser] = []

    func requestAuthorization(for browser: Browser) async throws -> Bool {
        requestedBrowsers.append(browser)
        return true
    }
}

@MainActor
private final class BookmarkAccessServiceDouble: BookmarkAccessManaging {
    let snapshot: BookmarkAccessSnapshot

    init(snapshot: BookmarkAccessSnapshot) {
        self.snapshot = snapshot
    }

    func inspectAccess() async -> BookmarkAccessSnapshot { snapshot }

    func testAccess(
        for browser: Browser,
        chromeProfileDirectory: String?
    ) async -> BookmarkAccessStatus {
        .ok
    }

    func reauthorize(_ browser: Browser) async throws -> Bool { true }
}

@MainActor
private final class ChromeProfileSelectionStoreDouble:
    ChromeProfileSelectionStoring
{
    private var selected: String?
    private(set) var savedDirectories: [String] = []

    init(selected: String?) {
        self.selected = selected
    }

    func selectedProfileDirectory() -> String? { selected }

    func saveSelectedProfileDirectory(_ directory: String) {
        selected = directory
        savedDirectories.append(directory)
    }
}
