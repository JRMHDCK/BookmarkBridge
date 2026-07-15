//
//  FileAccessProviderTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

/// A spy controller: configurable outcomes and start/stop counters, so tests can
/// assert resource balancing without touching the real filesystem or Safari.
private final class SpySecurityScopedFileController: SecurityScopedFileControlling, @unchecked Sendable {
    var exists = true
    var readable = true
    var startReturnValue = true

    private(set) var startCount = 0
    private(set) var stopCount = 0

    func fileExists(at url: URL) -> Bool { exists }
    func isReadable(at url: URL) -> Bool { readable }
    func startAccessing(_ url: URL) -> Bool {
        startCount += 1
        return startReturnValue
    }
    func stopAccessing(_ url: URL) {
        stopCount += 1
    }
}

@Suite("SandboxFileAccessProvider")
struct FileAccessProviderTests {

    private func location(_ path: String = "/tmp/bookmarks-under-test.plist") -> BrowserLocation {
        BrowserLocation(browser: .safari, fileURL: URL(fileURLWithPath: path))
    }

    // MARK: - Success

    @Test("Grants read-only access and returns the body's result")
    func successfulOpen() throws {
        let spy = SpySecurityScopedFileController()
        let provider = SandboxFileAccessProvider(controller: spy)

        let result = try provider.withReadOnlyAccess(to: location()) { url in
            url.lastPathComponent
        }

        #expect(result == "bookmarks-under-test.plist")
        #expect(spy.startCount == 1)
        #expect(spy.stopCount == 1)
    }

    @Test("Reads a real temporary file end-to-end (system controller)")
    func readsRealTemporaryFile() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: "bb-\(UUID().uuidString).bin")
        let payload = Data("bookmark bytes".utf8)
        try payload.write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let provider = SandboxFileAccessProvider()
        let read = try provider.withReadOnlyAccess(
            to: BrowserLocation(browser: .safari, fileURL: fileURL)
        ) { url in
            try Data(contentsOf: url)
        }

        #expect(read == payload)
    }

    // MARK: - Refusals (access always released)

    @Test("Throws sourceNotFound when the file is missing, still releasing access")
    func missingFile() {
        let spy = SpySecurityScopedFileController()
        spy.exists = false
        let provider = SandboxFileAccessProvider(controller: spy)

        #expect(throws: BookmarkError.sourceNotFound(.safari)) {
            try provider.withReadOnlyAccess(to: location()) { _ in }
        }
        #expect(spy.startCount == 1)
        #expect(spy.stopCount == 1)
    }

    @Test("Throws accessDenied when the file is not readable, still releasing access")
    func notReadable() {
        let spy = SpySecurityScopedFileController()
        spy.readable = false
        let loc = location()
        let provider = SandboxFileAccessProvider(controller: spy)

        #expect(throws: BookmarkError.accessDenied(loc)) {
            try provider.withReadOnlyAccess(to: loc) { _ in }
        }
        #expect(spy.startCount == 1)
        #expect(spy.stopCount == 1)
    }

    // MARK: - Close on error / no leak

    @Test("Releases access even when the body throws")
    func closesOnBodyError() {
        struct Boom: Error {}
        let spy = SpySecurityScopedFileController()
        let provider = SandboxFileAccessProvider(controller: spy)

        #expect(throws: Boom.self) {
            try provider.withReadOnlyAccess(to: location()) { _ -> Void in throw Boom() }
        }
        #expect(spy.startCount == 1)
        #expect(spy.stopCount == 1)
    }

    @Test("Does not release when access was never started (no over-release)")
    func noOverReleaseWhenStartFails() throws {
        let spy = SpySecurityScopedFileController()
        spy.startReturnValue = false
        let provider = SandboxFileAccessProvider(controller: spy)

        _ = try provider.withReadOnlyAccess(to: location()) { $0.lastPathComponent }

        #expect(spy.startCount == 1)
        #expect(spy.stopCount == 0)
    }

    @Test("Start and stop stay balanced across success and failure (no leak)")
    func balancedAcrossScenarios() {
        let spy = SpySecurityScopedFileController()
        let provider = SandboxFileAccessProvider(controller: spy)

        _ = try? provider.withReadOnlyAccess(to: location()) { $0.lastPathComponent }
        spy.readable = false
        _ = try? provider.withReadOnlyAccess(to: location()) { $0.lastPathComponent }

        #expect(spy.startCount == 2)
        #expect(spy.stopCount == 2)
    }
}
