//
//  ChromeBookmarkReader.swift
//  BookmarkBridge
//

import Foundation

/// Reads a single Chrome profile's bookmarks into an immutable `BookmarkTree`.
///
/// A **pure orchestrator** — no parsing, no UI. Because Chrome access is granted
/// at the **directory** level (one security-scoped bookmark for the Chrome data
/// folder), the reader opens read-only access to that directory and then reads
/// the profile's `Bookmarks` file within the granted subtree, decodes it, and
/// stamps the capture time. It reads only that one file — never history,
/// passwords, cookies, or other Chrome data.
nonisolated struct ChromeBookmarkReader: BookmarkReading {
    let source: BookmarkSource

    /// The Chrome data directory (the security-scoped resource to open).
    private let directoryLocation: BrowserLocation
    /// The profile's `Bookmarks` file within that directory.
    private let bookmarksURL: URL
    private let fileAccess: FileAccessProviding
    private let decoder: BookmarkDecoding
    private let readData: @Sendable (URL) throws -> Data
    private let now: @Sendable () -> Date

    init(
        source: BookmarkSource,
        directoryLocation: BrowserLocation,
        bookmarksURL: URL,
        fileAccess: FileAccessProviding = SandboxFileAccessProvider(),
        decoder: BookmarkDecoding = ChromeBookmarkDecoder(),
        readData: @escaping @Sendable (URL) throws -> Data = { try Data(contentsOf: $0) },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.source = source
        self.directoryLocation = directoryLocation
        self.bookmarksURL = bookmarksURL
        self.fileAccess = fileAccess
        self.decoder = decoder
        self.readData = readData
        self.now = now
    }

    /// Writable in V1 only when this profile uses the local `Bookmarks` file
    /// (`kLocalOrSyncableBookmarksFileName`); account files are read-only.
    var writableLocation: BrowserLocation? {
        bookmarksURL.lastPathComponent == "Bookmarks"
            ? BrowserLocation(browser: source.browser, fileURL: bookmarksURL)
            : nil
    }

    /// The Chrome data directory to open while writing (the granted
    /// security-scoped resource). Present only when the profile is writable.
    var writableScopeDirectory: BrowserLocation? {
        writableLocation == nil ? nil : directoryLocation
    }

    func readBookmarkTree() async throws -> BookmarkTree {
        // Open read-only access to the Chrome directory, then read only this
        // profile's Bookmarks file within it.
        let data = try fileAccess.withReadOnlyAccess(to: directoryLocation) { _ in
            try readData(bookmarksURL)
        }
        let decoded = try decoder.decodeTree(from: data)
        return BookmarkTree(browser: source.browser, roots: decoded.roots, capturedAt: now())
    }
}
