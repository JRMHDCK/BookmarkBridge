//
//  ApplicationSupportBookmarkStoreTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("ApplicationSupportBookmarkStore")
struct ApplicationSupportBookmarkStoreTests {

    /// A fresh, unique temporary directory per test — never Application Support.
    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "bb-store-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    private func makeStore() -> (ApplicationSupportBookmarkStore, URL) {
        let dir = temporaryDirectory()
        return (ApplicationSupportBookmarkStore(directory: dir), dir)
    }

    private func cleanup(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: - Round trip

    @Test("Saves then loads the same bookmark data")
    func saveThenLoad() throws {
        let (store, dir) = makeStore()
        defer { cleanup(dir) }

        let payload = Data([0x01, 0x02, 0x03, 0xFF])
        try store.saveBookmark(payload, for: .safari)

        #expect(try store.loadBookmark(for: .safari) == payload)
    }

    @Test("Creates the Application Support directory on demand")
    func createsDirectory() throws {
        let (store, dir) = makeStore()
        defer { cleanup(dir) }

        #expect(!FileManager.default.fileExists(atPath: dir.path(percentEncoded: false)))
        try store.saveBookmark(Data([0xAB]), for: .safari)
        #expect(FileManager.default.fileExists(atPath: dir.path(percentEncoded: false)))
    }

    // MARK: - Absence

    @Test("Returns nil when no bookmark has been stored")
    func absentReturnsNil() throws {
        let (store, dir) = makeStore()
        defer { cleanup(dir) }

        #expect(try store.loadBookmark(for: .safari) == nil)
    }

    // MARK: - Atomic replacement

    @Test("Replacing a bookmark keeps only the latest value")
    func atomicReplacement() throws {
        let (store, dir) = makeStore()
        defer { cleanup(dir) }

        try store.saveBookmark(Data([0x01]), for: .safari)
        try store.saveBookmark(Data([0x02, 0x02]), for: .safari)

        #expect(try store.loadBookmark(for: .safari) == Data([0x02, 0x02]))
    }

    // MARK: - Corruption & versioning

    @Test("Throws corruptedData when the file is not a valid envelope")
    func corruptedData() throws {
        let (store, dir) = makeStore()
        defer { cleanup(dir) }

        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appending(path: "SafariAccessBookmark.plist")
        try Data("garbage, not a plist".utf8).write(to: fileURL)

        #expect(throws: BookmarkStoreError.corruptedData) {
            _ = try store.loadBookmark(for: .safari)
        }
    }

    @Test("Throws unsupportedVersion for a future format version")
    func unsupportedVersion() throws {
        let (store, dir) = makeStore()
        defer { cleanup(dir) }

        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let envelope = ApplicationSupportBookmarkStore.Envelope(version: 999, bookmark: Data([0x01]))
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        try encoder.encode(envelope).write(to: dir.appending(path: "SafariAccessBookmark.plist"))

        #expect(throws: BookmarkStoreError.unsupportedVersion(999)) {
            _ = try store.loadBookmark(for: .safari)
        }
    }

    // MARK: - Deletion

    @Test("Clearing removes the stored bookmark")
    func clear() throws {
        let (store, dir) = makeStore()
        defer { cleanup(dir) }

        try store.saveBookmark(Data([0x09]), for: .safari)
        try store.clearBookmark(for: .safari)

        #expect(try store.loadBookmark(for: .safari) == nil)
    }

    @Test("Clearing a missing bookmark is a no-op")
    func clearWhenAbsent() throws {
        let (store, dir) = makeStore()
        defer { cleanup(dir) }

        #expect(throws: Never.self) {
            try store.clearBookmark(for: .safari)
        }
    }

    // MARK: - Isolation between browsers

    @Test("Stores bookmarks per browser independently")
    func perBrowserIsolation() throws {
        let (store, dir) = makeStore()
        defer { cleanup(dir) }

        try store.saveBookmark(Data([0x0A]), for: .safari)
        #expect(try store.loadBookmark(for: .chrome) == nil)
        #expect(try store.loadBookmark(for: .safari) == Data([0x0A]))
    }

    // MARK: - Permissions

    @Test("Persists with owner-only file permissions")
    func filePermissions() throws {
        let (store, dir) = makeStore()
        defer { cleanup(dir) }

        try store.saveBookmark(Data([0x01]), for: .safari)
        let attributes = try FileManager.default.attributesOfItem(
            atPath: dir.appending(path: "SafariAccessBookmark.plist").path(percentEncoded: false)
        )
        let permissions = try #require(attributes[.posixPermissions] as? NSNumber)
        #expect(permissions.int16Value == 0o600)
    }
}
