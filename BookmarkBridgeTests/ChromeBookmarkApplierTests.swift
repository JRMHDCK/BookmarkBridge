//
//  ChromeBookmarkApplierTests.swift
//  BookmarkBridgeTests
//
//  Temporary files only — never a real Chrome profile.
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("ChromeBookmarkApplier")
struct ChromeBookmarkApplierTests {

    private struct StubDetector: RunningBrowserDetecting {
        let running: Set<Browser>
        func isRunning(_ browser: Browser) -> Bool { running.contains(browser) }
    }

    private final class SequencedDetector: RunningBrowserDetecting, @unchecked Sendable {
        private let responses: [Bool]
        private var index = 0
        private let lock = NSLock()

        init(_ responses: [Bool]) {
            self.responses = responses
        }

        func isRunning(_ browser: Browser) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            let response = responses[min(index, responses.count - 1)]
            index += 1
            return response
        }
    }

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ApplierTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Writes the Chrome fixture to a temp "Bookmarks" file and returns the pieces.
    private func makeFixture() throws -> (location: BrowserLocation, backup: FileBookmarkBackup, profileDir: URL) {
        let profileDir = tempDir()
        let bookmarksURL = profileDir.appendingPathComponent("Bookmarks", isDirectory: false)
        try ChromeBookmarksFixture.data().write(to: bookmarksURL)
        return (
            BrowserLocation(browser: .chrome, fileURL: bookmarksURL),
            FileBookmarkBackup(rootDirectory: tempDir()),
            profileDir
        )
    }

    private func newBookmark() -> Bookmark {
        Bookmark(id: BookmarkID("n"), title: "New Site", url: URL(string: "https://new.example/")!)
    }

    @Test("Refuses to write while Chrome is running, leaving the file untouched")
    func refusesWhenChromeRunning() async throws {
        let f = try makeFixture()
        let applier = ChromeBookmarkApplier(detector: StubDetector(running: [.chrome]), backup: f.backup)
        let scope = BrowserLocation(browser: .chrome, fileURL: f.profileDir)
        let before = try Data(contentsOf: f.location.fileURL)

        await #expect(throws: ChromeWriteError.browserIsRunning) {
            try await applier.apply([newBookmark()], to: f.location, in: scope, now: now)
        }
        #expect(try Data(contentsOf: f.location.fileURL) == before)   // unchanged
    }

    @Test("Creates an absent Bookmarks.bak atomically")
    func writesAndBacksUp() async throws {
        let f = try makeFixture()
        let controller = SpySecurityScopedFileController()
        let applier = ChromeBookmarkApplier(
            detector: StubDetector(running: []),
            backup: f.backup,
            fileController: controller
        )
        let scope = BrowserLocation(browser: .chrome, fileURL: f.profileDir)
        let original = try Data(contentsOf: f.location.fileURL)

        let result = try await applier.apply([newBookmark()], to: f.location, in: scope, now: now)
        let handle = result.backup

        // The addition landed.
        let tree = try ChromeBookmarkDecoder().decodeTree(from: Data(contentsOf: f.location.fileURL))
        #expect(tree.allBookmarks.contains { $0.title == "New Site" })

        // The backup holds the pre-write bytes.
        #expect(FileManager.default.fileExists(atPath: handle.fileURL.path))
        #expect(try Data(contentsOf: handle.fileURL) == original)

        // Bookmarks.bak holds the pre-write bytes too.
        let bakURL = f.profileDir.appendingPathComponent("Bookmarks.bak", isDirectory: false)
        #expect(try Data(contentsOf: bakURL) == original)
        #expect(result.addedCount == 1)
        #expect(controller.startCount == 1)
        #expect(controller.stopCount == 1)
    }

    @Test("Atomically replaces an existing Bookmarks.bak")
    func replacesExistingBak() async throws {
        let f = try makeFixture()
        let controller = SpySecurityScopedFileController()
        let applier = ChromeBookmarkApplier(
            detector: StubDetector(running: []),
            backup: f.backup,
            fileController: controller
        )
        let scope = BrowserLocation(browser: .chrome, fileURL: f.profileDir)
        let original = try Data(contentsOf: f.location.fileURL)
        let bakURL = f.profileDir.appendingPathComponent("Bookmarks.bak", isDirectory: false)
        try Data("old backup".utf8).write(to: bakURL)

        _ = try await applier.apply([newBookmark()], to: f.location, in: scope, now: now)

        #expect(try Data(contentsOf: bakURL) == original)
        #expect(controller.startCount == 1)
        #expect(controller.stopCount == 1)
    }

    @Test("Fails explicitly when the security scope does not allow writing")
    func scopeDeniedIsExplicit() async throws {
        let f = try makeFixture()
        let controller = SpySecurityScopedFileController()
        controller.startReturnValue = false
        let applier = ChromeBookmarkApplier(
            detector: StubDetector(running: []),
            backup: f.backup,
            fileController: controller
        )
        let scope = BrowserLocation(browser: .chrome, fileURL: f.profileDir)
        let original = try Data(contentsOf: f.location.fileURL)

        do {
            _ = try await applier.apply([newBookmark()], to: f.location, in: scope, now: now)
            Issue.record("Expected security scope denial")
        } catch ChromeWriteError.securityScopeDenied(let diagnostic) {
            #expect(diagnostic.stage == "ouverture du security scope")
            #expect(diagnostic.domain == NSPOSIXErrorDomain)
            #expect(diagnostic.code == 1)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(try Data(contentsOf: f.location.fileURL) == original)
        #expect(FileManager.default.fileExists(atPath: f.profileDir.appendingPathComponent("Bookmarks.bak").path) == false)
        #expect(controller.startCount == 1)
        #expect(controller.stopCount == 0)
    }

    @Test("Two successive applications do not duplicate an existing URL")
    func twoSuccessiveApplicationsAreIdempotent() async throws {
        let f = try makeFixture()
        let controller = SpySecurityScopedFileController()
        let applier = ChromeBookmarkApplier(
            detector: StubDetector(running: []),
            backup: f.backup,
            fileController: controller
        )
        let scope = BrowserLocation(browser: .chrome, fileURL: f.profileDir)
        let bookmark = Bookmark(
            id: BookmarkID("canonical"),
            title: "Canonical",
            url: URL(string: "https://new.example/page")!
        )
        let trackedDuplicate = Bookmark(
            id: BookmarkID("tracked"),
            title: "Tracked duplicate",
            url: URL(string: "https://new.example/page/?utm_source=test")!
        )

        let firstResult = try await applier.apply([bookmark], to: f.location, in: scope, now: now)
        let afterFirstApply = try Data(contentsOf: f.location.fileURL)
        let secondResult = try await applier.apply([trackedDuplicate], to: f.location, in: scope, now: now)
        let afterSecondApply = try Data(contentsOf: f.location.fileURL)

        let tree = try ChromeBookmarkDecoder().decodeTree(from: afterSecondApply)
        let key = BookmarkMatchKey.key(for: bookmark.url)
        #expect(tree.allBookmarks.filter { BookmarkMatchKey.key(for: $0.url) == key }.count == 1)
        #expect(afterSecondApply == afterFirstApply)
        #expect(firstResult.addedCount == 1)
        #expect(secondResult.addedCount == 0)
        #expect(controller.startCount == 2)
        #expect(controller.stopCount == 2)
    }

    @Test("Refuses to write a synced account bookmarks file (V1 read-only)")
    func refusesAccountBookmarks() async throws {
        let profileDir = tempDir()
        let accountURL = profileDir.appendingPathComponent("AccountBookmarks", isDirectory: false)
        try ChromeBookmarksFixture.data().write(to: accountURL)
        let location = BrowserLocation(browser: .chrome, fileURL: accountURL)
        let applier = ChromeBookmarkApplier(detector: StubDetector(running: []), backup: FileBookmarkBackup(rootDirectory: tempDir()))
        let scope = BrowserLocation(browser: .chrome, fileURL: profileDir)
        let before = try Data(contentsOf: accountURL)

        await #expect(throws: ChromeWriteError.accountBookmarksAreReadOnly) {
            try await applier.apply([newBookmark()], to: location, in: scope, now: now)
        }
        #expect(try Data(contentsOf: accountURL) == before)   // untouched
    }

    @Test("The write is reversible via the returned backup handle")
    func writeIsReversible() async throws {
        let f = try makeFixture()
        let controller = SpySecurityScopedFileController()
        let applier = ChromeBookmarkApplier(
            detector: StubDetector(running: []),
            backup: f.backup,
            fileController: controller
        )
        let scope = BrowserLocation(browser: .chrome, fileURL: f.profileDir)
        let original = try Data(contentsOf: f.location.fileURL)

        let handle = try await applier.apply([newBookmark()], to: f.location, in: scope, now: now).backup
        #expect(try Data(contentsOf: f.location.fileURL) != original)   // changed

        try await f.backup.restore(handle)
        #expect(try Data(contentsOf: f.location.fileURL) == original)   // fully restored
    }

    @Test("Refuses the final replacement if Chrome starts during the transaction")
    func refusesFinalReplacementWhenChromeStarts() async throws {
        let f = try makeFixture()
        let controller = SpySecurityScopedFileController()
        let detector = SequencedDetector([false, true])
        let applier = ChromeBookmarkApplier(
            detector: detector,
            backup: f.backup,
            fileController: controller
        )
        let scope = BrowserLocation(browser: .chrome, fileURL: f.profileDir)
        let original = try Data(contentsOf: f.location.fileURL)

        var retainedHandle: BackupHandle?
        do {
            _ = try await applier.apply([newBookmark()], to: f.location, in: scope, now: now)
            Issue.record("Expected Chrome launch to cancel the final replacement")
        } catch ChromeWriteError.browserStartedDuringTransaction(let handle) {
            retainedHandle = handle
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        let handle = try #require(retainedHandle)
        #expect(try Data(contentsOf: f.location.fileURL) == original)
        #expect(try Data(contentsOf: handle.fileURL) == original)
        #expect(controller.startCount == 1)
        #expect(controller.stopCount == 1)
    }

    @Test("A .bak failure is explicit, preserves the backup handle, and closes the scope")
    func bakFailurePreservesBackup() async throws {
        let f = try makeFixture()
        let controller = SpySecurityScopedFileController()
        let applier = ChromeBookmarkApplier(
            detector: StubDetector(running: []),
            backup: f.backup,
            fileController: controller
        )
        let scope = BrowserLocation(browser: .chrome, fileURL: f.profileDir)
        let original = try Data(contentsOf: f.location.fileURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: f.profileDir.path)
        defer {
            do {
                try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: f.profileDir.path)
            } catch {
                Issue.record("Could not restore fixture permissions: \(error)")
            }
        }

        var retainedHandle: BackupHandle?
        do {
            _ = try await applier.apply([newBookmark()], to: f.location, in: scope, now: now)
            #expect(Bool(false), "Expected Bookmarks.bak creation to fail")
        } catch ChromeWriteError.bakCreationFailed(let handle, let diagnostic) {
            retainedHandle = handle
            #expect(diagnostic.stage == "création de Bookmarks.bak")
            #expect(diagnostic.domain == NSCocoaErrorDomain)
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }

        let handle = try #require(retainedHandle)
        #expect(try Data(contentsOf: handle.fileURL) == original)
        #expect(try Data(contentsOf: f.location.fileURL) == original)
        #expect(controller.startCount == 1)
        #expect(controller.stopCount == 1)
    }
}
