//
//  ApplicationSupportBookmarkStore.swift
//  BookmarkBridge
//

import Foundation

/// A `BookmarkStore` backed by a private file under
/// `Application Support/BookmarkBridge/`.
///
/// - Stores a small **versioned** binary-plist envelope containing only the
///   opaque bookmark `Data` — never favourite content.
/// - Writes **atomically** and restricts permissions to the current user
///   (directory `0700`, file `0600`).
/// - Creates the containing directory on demand.
/// - Local storage only (no iCloud). The base directory is injectable so tests
///   run entirely in a temporary directory.
nonisolated struct ApplicationSupportBookmarkStore: BookmarkStore {

    /// Current on-disk format version.
    static let formatVersion = 1

    /// The versioned envelope actually written to disk.
    struct Envelope: Codable, Equatable {
        var version: Int
        var bookmark: Data
    }

    private let directory: URL

    /// Creates a store rooted at an explicit directory (used by tests).
    init(directory: URL) {
        self.directory = directory
    }

    /// Creates a store under the user's Application Support directory. The
    /// directory itself is created lazily on first save (`ensureDirectory()`),
    /// so this is non-throwing.
    static func inApplicationSupport() -> ApplicationSupportBookmarkStore {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first
            ?? FileManager.default.temporaryDirectory
        return ApplicationSupportBookmarkStore(
            directory: base.appending(path: "BookmarkBridge", directoryHint: .isDirectory)
        )
    }

    // MARK: - BookmarkStore

    func loadBookmark(for browser: Browser) throws -> Data? {
        let url = fileURL(for: browser)
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            return nil
        }

        let raw = try Data(contentsOf: url)
        let envelope: Envelope
        do {
            envelope = try PropertyListDecoder().decode(Envelope.self, from: raw)
        } catch {
            throw BookmarkStoreError.corruptedData
        }
        guard envelope.version == Self.formatVersion else {
            throw BookmarkStoreError.unsupportedVersion(envelope.version)
        }
        return envelope.bookmark
    }

    func saveBookmark(_ bookmark: Data, for browser: Browser) throws {
        try ensureDirectory()

        let envelope = Envelope(version: Self.formatVersion, bookmark: bookmark)
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let encoded = try encoder.encode(envelope)

        let url = fileURL(for: browser)
        try encoded.write(to: url, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path(percentEncoded: false))
    }

    func clearBookmark(for browser: Browser) throws {
        let url = fileURL(for: browser)
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return }
        try FileManager.default.removeItem(at: url)
    }

    // MARK: - Paths

    private func fileURL(for browser: Browser) -> URL {
        directory.appending(path: "\(browser.rawValue.capitalized)AccessBookmark.plist", directoryHint: .notDirectory)
    }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    }
}
