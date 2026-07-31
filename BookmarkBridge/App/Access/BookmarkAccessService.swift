//
//  BookmarkAccessService.swift
//  BookmarkBridge
//

import Foundation

@MainActor
final class BookmarkAccessService: BookmarkAccessManaging, Sendable {
    private let store: any BookmarkStore
    private let resolver: any SecurityScopedBookmarkResolving
    private let fileController: any SecurityScopedFileControlling
    private let requester: any BookmarkAuthorizationRequesting
    private let profileLocator: any ChromeProfileLocating
    private let homeDirectory: URL
    private let readData: @Sendable (URL) throws -> Data

    init(
        store: any BookmarkStore,
        resolver: any SecurityScopedBookmarkResolving,
        fileController: any SecurityScopedFileControlling,
        requester: any BookmarkAuthorizationRequesting,
        profileLocator: any ChromeProfileLocating = DefaultChromeProfileLocator(),
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        readData: @escaping @Sendable (URL) throws -> Data = {
            try Data(contentsOf: $0, options: .mappedIfSafe)
        }
    ) {
        self.store = store
        self.resolver = resolver
        self.fileController = fileController
        self.requester = requester
        self.profileLocator = profileLocator
        self.homeDirectory = Self.userHomeDirectory(from: homeDirectory)
        self.readData = readData
    }

    func inspectAccess() async -> BookmarkAccessSnapshot {
        BookmarkAccessSnapshot(
            safari: inspectSafari(),
            chrome: inspectChrome()
        )
    }

    func testAccess(
        for browser: Browser,
        chromeProfileDirectory: String?
    ) async -> BookmarkAccessStatus {
        switch browser {
        case .safari:
            let resolution = resolve(.safari)
            guard case .resolved(let url) = resolution else {
                return status(of: resolution)
            }
            return withAccess(to: url) {
                do {
                    _ = try readData(url)
                    return .ok
                } catch {
                    return fileController.fileExists(at: url)
                        ? .authorizationInvalid
                        : .fileMissing
                }
            }
        case .chrome:
            let resolution = resolve(.chrome)
            guard case .resolved(let directoryURL) = resolution else {
                return status(of: resolution)
            }
            return withAccess(to: directoryURL) {
                guard let chromeProfileDirectory else {
                    return .fileMissing
                }
                guard let profile = try? profileLocator
                    .profiles(in: directoryURL)
                    .first(where: {
                        $0.profileDirectoryName == chromeProfileDirectory
                    }) else {
                    return .fileMissing
                }
                let bookmarksURL = displayedBookmarksURL(for: profile)
                do {
                    _ = try readData(bookmarksURL)
                    return .ok
                } catch {
                    return fileController.fileExists(at: bookmarksURL)
                        ? .authorizationInvalid
                        : .fileMissing
                }
            }
        }
    }

    func reauthorize(_ browser: Browser) async throws -> Bool {
        try await requester.requestAuthorization(for: browser)
    }

    private var detectedSafariURL: URL {
        homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Safari", isDirectory: true)
            .appendingPathComponent("Bookmarks.plist", isDirectory: false)
    }

    private static func userHomeDirectory(from reportedHomeDirectory: URL) -> URL {
        guard reportedHomeDirectory.lastPathComponent == "Data" else {
            return reportedHomeDirectory
        }
        let containerDirectory = reportedHomeDirectory
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        guard containerDirectory.lastPathComponent == "Containers" else {
            return reportedHomeDirectory
        }
        return containerDirectory
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func inspectSafari() -> SafariBookmarkAccess {
        let resolution = resolve(.safari)
        switch resolution {
        case .missing:
            return SafariBookmarkAccess(
                detectedURL: detectedSafariURL,
                authorizedURL: nil,
                status: .authorizationMissing
            )
        case .invalid:
            return SafariBookmarkAccess(
                detectedURL: detectedSafariURL,
                authorizedURL: nil,
                status: .authorizationInvalid
            )
        case .resolved(let url):
            let status: BookmarkAccessStatus = withAccess(to: url) {
                guard fileController.fileExists(at: url) else {
                    return .fileMissing
                }
                return fileController.isReadable(at: url)
                    ? .ok
                    : .authorizationInvalid
            }
            return SafariBookmarkAccess(
                detectedURL: detectedSafariURL,
                authorizedURL: url,
                status: status
            )
        }
    }

    private func inspectChrome() -> ChromeBookmarkAccess {
        let resolution = resolve(.chrome)
        guard case .resolved(let directoryURL) = resolution else {
            return ChromeBookmarkAccess(
                authorizedDirectoryURL: nil,
                profiles: [],
                status: status(of: resolution)
            )
        }
        return withAccess(to: directoryURL) {
            guard fileController.fileExists(at: directoryURL) else {
                return ChromeBookmarkAccess(
                    authorizedDirectoryURL: directoryURL,
                    profiles: [],
                    status: .fileMissing
                )
            }
            guard fileController.isReadable(at: directoryURL) else {
                return ChromeBookmarkAccess(
                    authorizedDirectoryURL: directoryURL,
                    profiles: [],
                    status: .authorizationInvalid
                )
            }
            let profiles: [ChromeProfileAccess]
            do {
                let names = (try? readData(profileLocator.localStateURL(
                    in: directoryURL
                ))).map(ChromeLocalState.profileNames(from:)) ?? [:]
                profiles = try profileLocator.profiles(in: directoryURL).map {
                    profile in
                    ChromeProfileAccess(
                        directoryName: profile.profileDirectoryName,
                        profileName: names[profile.profileDirectoryName]
                            ?? profile.profileDirectoryName,
                        bookmarksURL: displayedBookmarksURL(for: profile)
                    )
                }
            } catch {
                return ChromeBookmarkAccess(
                    authorizedDirectoryURL: directoryURL,
                    profiles: [],
                    status: .fileMissing
                )
            }
            return ChromeBookmarkAccess(
                authorizedDirectoryURL: directoryURL,
                profiles: profiles,
                status: profiles.isEmpty ? .fileMissing : .ok
            )
        }
    }

    private enum AuthorizationResolution {
        case missing
        case invalid
        case resolved(URL)
    }

    private func resolve(_ browser: Browser) -> AuthorizationResolution {
        let bookmark: Data
        do {
            guard let stored = try store.loadBookmark(for: browser) else {
                return .missing
            }
            bookmark = stored
        } catch {
            return .invalid
        }
        do {
            let resolved = try resolver.resolve(bookmark)
            guard isExpectedLocation(resolved.url, for: browser) else {
                return .invalid
            }
            return .resolved(resolved.url)
        } catch {
            return .invalid
        }
    }

    private func status(
        of resolution: AuthorizationResolution
    ) -> BookmarkAccessStatus {
        switch resolution {
        case .missing: .authorizationMissing
        case .invalid: .authorizationInvalid
        case .resolved: .ok
        }
    }

    private func withAccess<T>(
        to url: URL,
        perform: () -> T
    ) -> T {
        let started = fileController.startAccessing(url)
        defer {
            if started {
                fileController.stopAccessing(url)
            }
        }
        return perform()
    }

    private func isExpectedLocation(_ url: URL, for browser: Browser) -> Bool {
        let path = url.path(percentEncoded: false)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        switch browser {
        case .safari:
            return path.hasSuffix(BrowserAccessCoordinator.safariPathSuffix)
        case .chrome:
            return path.hasSuffix(
                BrowserAccessCoordinator.chromeDirectorySuffix
            )
        }
    }

    private func displayedBookmarksURL(
        for profile: ChromeProfileLocation
    ) -> URL {
        switch profile.storage {
        case .bookmarks(let url), .account(let url):
            url
        case .ambiguous(let bookmarks, account: _):
            bookmarks
        }
    }
}
