//
//  ChromeSourceProvider.swift
//  BookmarkBridge
//

import Foundation

/// Discovers Chrome's profiles and provides a reader per profile.
///
/// Orchestration only: it resolves the authorized Chrome directory, opens
/// read-only access once to enumerate profiles and read `Local State` (for the
/// user-facing names), then builds a `ChromeBookmarkReader` per profile. Each
/// reader reads its own `Bookmarks` file independently. It reads only
/// `Local State` and the profiles' `Bookmarks` files — nothing else.
nonisolated struct ChromeSourceProvider: BrowserSourceProviding {
    let browser: Browser = .chrome

    private let directoryLocator: BookmarkSourceLocating
    private let fileAccess: FileAccessProviding
    private let profileLocator: ChromeProfileLocating
    private let decoder: BookmarkDecoding
    private let readData: @Sendable (URL) throws -> Data
    private let now: @Sendable () -> Date

    init(
        directoryLocator: BookmarkSourceLocating,
        fileAccess: FileAccessProviding = SandboxFileAccessProvider(),
        profileLocator: ChromeProfileLocating = DefaultChromeProfileLocator(),
        decoder: BookmarkDecoding = ChromeBookmarkDecoder(),
        readData: @escaping @Sendable (URL) throws -> Data = { try Data(contentsOf: $0) },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.directoryLocator = directoryLocator
        self.fileAccess = fileAccess
        self.profileLocator = profileLocator
        self.decoder = decoder
        self.readData = readData
        self.now = now
    }

    func makeReaders() async throws -> [BookmarkReading] {
        // Resolve the authorized Chrome directory (throws authorizationRequired
        // when access has not been granted).
        let directoryLocation = try directoryLocator.locate(.chrome)

        // Open access once to enumerate profiles and read Local State names.
        let discovery = try fileAccess.withReadOnlyAccess(to: directoryLocation) { directoryURL in
            let profiles = try profileLocator.profiles(in: directoryURL).map { profile in
                resolvingEmptyAccountFile(profile)
            }
            let localStateData = try? readData(profileLocator.localStateURL(in: directoryURL))
            let names = localStateData.map(ChromeLocalState.profileNames(from:)) ?? [:]
            return Discovery(profiles: profiles, names: names)
        }

        return discovery.profiles.map { profile -> any BookmarkReading in
            let userName = discovery.names[profile.profileDirectoryName] ?? profile.profileDirectoryName
            let source = BookmarkSource(
                browser: .chrome,
                profile: profile.profileDirectoryName,
                displayName: "Chrome — \(userName)"
            )
            switch profile.storage {
            case .bookmarks(let bookmarksURL), .account(let bookmarksURL):
                return ChromeBookmarkReader(
                    source: source,
                    directoryLocation: directoryLocation,
                    bookmarksURL: bookmarksURL,
                    fileAccess: fileAccess,
                    decoder: decoder,
                    readData: readData,
                    now: now
                )
            case .ambiguous:
                // Both files present — surface it, don't guess.
                return AmbiguousChromeProfileReader(source: source)
            }
        }
    }

    /// When a profile exposes both files but `AccountBookmarks` is **empty**, the
    /// local `Bookmarks` file already holds everything, so use it (no ambiguity,
    /// no error). Profiles whose account file actually has bookmarks stay
    /// ambiguous. Must be called inside the granted read-only access.
    private func resolvingEmptyAccountFile(_ profile: ChromeProfileLocation) -> ChromeProfileLocation {
        guard case .ambiguous(let bookmarks, let account) = profile.storage else { return profile }
        if let data = try? readData(account),
           let tree = try? decoder.decodeTree(from: data),
           tree.bookmarkCount == 0 {
            return ChromeProfileLocation(profileDirectoryName: profile.profileDirectoryName, storage: .bookmarks(bookmarks))
        }
        return profile
    }

    private struct Discovery {
        let profiles: [ChromeProfileLocation]
        let names: [String: String]
    }
}
