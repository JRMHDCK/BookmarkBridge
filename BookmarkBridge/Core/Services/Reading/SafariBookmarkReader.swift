//
//  SafariBookmarkReader.swift
//  BookmarkBridge
//

import Foundation

/// Reads Safari's bookmarks into an immutable `BookmarkTree`.
///
/// This type is a **pure orchestrator** — it contains no parsing and no UI. It
/// coordinates the single-responsibility collaborators it is given:
///
/// 1. locate the file (`BookmarkSourceLocating`);
/// 2. obtain read-only, scoped access (`FileAccessProviding`);
/// 3. read the raw bytes (within the access scope);
/// 4. decode them (`BookmarkDecoding`), after access is released;
/// 5. stamp the capture time the decoder cannot know.
///
/// Resolving a security-scoped bookmark into a real URL is *not* this type's
/// concern: it simply reads whatever location the locator returns.
nonisolated struct SafariBookmarkReader: BookmarkReading {
    let browser: Browser = .safari

    private let locator: BookmarkSourceLocating
    private let fileAccess: FileAccessProviding
    private let decoder: BookmarkDecoding
    private let readData: @Sendable (URL) throws -> Data
    private let now: @Sendable () -> Date

    init(
        locator: BookmarkSourceLocating = SafariBookmarkSourceLocator(),
        fileAccess: FileAccessProviding = SandboxFileAccessProvider(),
        decoder: BookmarkDecoding = SafariBookmarkDecoder(),
        readData: @escaping @Sendable (URL) throws -> Data = { try Data(contentsOf: $0) },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.locator = locator
        self.fileAccess = fileAccess
        self.decoder = decoder
        self.readData = readData
        self.now = now
    }

    func readBookmarkTree() async throws -> BookmarkTree {
        // 1. Locate.
        let location = try locator.locate(browser)

        // 2 & 3. Read the bytes while holding read-only access; the scope is
        // released as soon as this returns (or throws).
        let data = try fileAccess.withReadOnlyAccess(to: location) { url in
            try readData(url)
        }

        // 4. Decode outside the access scope.
        let decoded = try decoder.decodeTree(from: data)

        // 5. Stamp the real capture time (the decoder leaves a sentinel).
        return BookmarkTree(browser: browser, roots: decoded.roots, capturedAt: now())
    }
}
