//
//  ChromeProfileLocating.swift
//  BookmarkBridge
//

import Foundation

/// Which bookmark storage file(s) a Chrome profile exposes.
///
/// Names per Chromium `bookmark_constants`: `Bookmarks` is
/// `kLocalOrSyncableBookmarksFileName`, `AccountBookmarks` is
/// `kAccountBookmarksFileName`. We make no assumption about sync status.
nonisolated enum ChromeBookmarkStorage: Hashable, Sendable {
    /// Only the `Bookmarks` file is present.
    case bookmarks(URL)
    /// Only the `AccountBookmarks` file is present.
    case account(URL)
    /// **Both** files are present. V1 does not pick one arbitrarily — the
    /// profile is surfaced as "two storages detected" pending an explicit,
    /// behaviour-based strategy.
    case ambiguous(bookmarks: URL, account: URL)
}

/// The on-disk location of one Chrome profile's bookmarks.
nonisolated struct ChromeProfileLocation: Hashable, Sendable {
    /// The profile's directory name (stable identity): "Default", "Profile 1", …
    let profileDirectoryName: String
    /// The bookmark storage file(s) this profile exposes.
    let storage: ChromeBookmarkStorage

    init(profileDirectoryName: String, storage: ChromeBookmarkStorage) {
        self.profileDirectoryName = profileDirectoryName
        self.storage = storage
    }
}

/// Locates Chrome's data directory and discovers its bookmark profiles.
///
/// Path computation is pure; profile enumeration reads the *given* (already
/// authorized) directory — it never reaches into other Chrome data. The Chrome
/// directory is passed in (rather than recomputed) because, under the sandbox,
/// the accessible URL comes from a resolved security-scoped bookmark.
nonisolated protocol ChromeProfileLocating: Sendable {
    /// Chrome's default data directory, from the user's home.
    func defaultChromeDirectory() -> URL

    /// The `Local State` file inside a given Chrome directory.
    func localStateURL(in chromeDirectory: URL) -> URL

    /// Profile directories that contain a `Bookmarks` file, discovered
    /// dynamically inside a given Chrome directory. Sorted by directory name.
    func profiles(in chromeDirectory: URL) throws -> [ChromeProfileLocation]
}

/// Production implementation over `FileManager`.
nonisolated struct DefaultChromeProfileLocator: ChromeProfileLocating {
    /// Directories that are never user profiles.
    private static let excludedDirectories: Set<String> = ["System Profile", "Guest Profile"]
    /// Per Chromium `bookmark_constants`: `kLocalOrSyncableBookmarksFileName`
    /// ("local or syncable" bookmarks).
    private static let bookmarksFileName = "Bookmarks"
    /// Per Chromium `bookmark_constants`: `kAccountBookmarksFileName` (account
    /// bookmarks). We make **no** assumption about sync status from the file's
    /// presence — discovery is purely by file existence.
    private static let accountBookmarksFileName = "AccountBookmarks"
    private static let localStateFileName = "Local State"

    private let homeDirectory: URL

    init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.homeDirectory = homeDirectory
    }

    func defaultChromeDirectory() -> URL {
        homeDirectory
            .appending(path: "Library", directoryHint: .isDirectory)
            .appending(path: "Application Support", directoryHint: .isDirectory)
            .appending(path: "Google", directoryHint: .isDirectory)
            .appending(path: "Chrome", directoryHint: .isDirectory)
    }

    func localStateURL(in chromeDirectory: URL) -> URL {
        chromeDirectory.appending(path: Self.localStateFileName, directoryHint: .notDirectory)
    }

    func profiles(in chromeDirectory: URL) throws -> [ChromeProfileLocation] {
        let fileManager = FileManager.default
        let entries: [URL]
        do {
            entries = try fileManager.contentsOfDirectory(
                at: chromeDirectory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            throw BookmarkError.sourceNotFound(.chrome)
        }

        let locations: [ChromeProfileLocation] = entries.compactMap { url in
            let name = url.lastPathComponent
            guard !Self.excludedDirectories.contains(name) else { return nil }

            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                return nil
            }

            // Discovery is by file existence only (no sync/sign-in inference):
            // `Bookmarks` alone, `AccountBookmarks` alone, or both. When both
            // exist, V1 makes no arbitrary choice — it flags the profile as
            // ambiguous rather than guessing which file is authoritative.
            let localURL = url.appending(path: Self.bookmarksFileName, directoryHint: .notDirectory)
            let accountURL = url.appending(path: Self.accountBookmarksFileName, directoryHint: .notDirectory)
            let hasLocal = fileManager.fileExists(atPath: localURL.path(percentEncoded: false))
            let hasAccount = fileManager.fileExists(atPath: accountURL.path(percentEncoded: false))

            let storage: ChromeBookmarkStorage
            switch (hasLocal, hasAccount) {
            case (true, true): storage = .ambiguous(bookmarks: localURL, account: accountURL)
            case (true, false): storage = .bookmarks(localURL)
            case (false, true): storage = .account(accountURL)
            case (false, false): return nil
            }

            return ChromeProfileLocation(profileDirectoryName: name, storage: storage)
        }

        return locations.sorted { $0.profileDirectoryName < $1.profileDirectoryName }
    }
}
