//
//  ChromeProfileLocating.swift
//  BookmarkBridge
//

import Foundation

/// The on-disk location of one Chrome profile's bookmarks.
nonisolated struct ChromeProfileLocation: Hashable, Sendable {
    /// The profile's directory name (stable identity): "Default", "Profile 1", …
    let profileDirectoryName: String
    /// The profile's `Bookmarks` file.
    let bookmarksURL: URL
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
    private static let bookmarksFileName = "Bookmarks"
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

            let bookmarksURL = url.appending(path: Self.bookmarksFileName, directoryHint: .notDirectory)
            guard fileManager.fileExists(atPath: bookmarksURL.path(percentEncoded: false)) else {
                return nil
            }

            return ChromeProfileLocation(profileDirectoryName: name, bookmarksURL: bookmarksURL)
        }

        return locations.sorted { $0.profileDirectoryName < $1.profileDirectoryName }
    }
}
