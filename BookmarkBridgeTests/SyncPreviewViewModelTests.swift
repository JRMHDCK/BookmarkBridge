//
//  SyncPreviewViewModelTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@MainActor
@Suite("SyncPreviewViewModel")
struct SyncPreviewViewModelTests {

    private let safari = BookmarkSource.singleProfile(.safari)
    private let chrome = BookmarkSource(browser: .chrome, profile: "Default", displayName: "Chrome — Perso")

    private func bookmark(_ id: String, _ title: String, _ url: String) -> BookmarkNode {
        .bookmark(Bookmark(id: BookmarkID(id), title: title, url: URL(string: url)!))
    }

    /// Safari: BookmarksBar › (Apple, Dev › Swift). Chrome: Barre › Hacker News.
    private func trees() -> (safari: BookmarkTree, chrome: BookmarkTree) {
        let dev = BookmarkFolder(id: BookmarkID("s.dev"), title: "Dev", children: [bookmark("s.sw", "Swift", "https://swift.org")])
        let sBar = BookmarkFolder(id: BookmarkID("s.bar"), title: "BookmarksBar", children: [
            bookmark("s.ap", "Apple", "https://apple.com"),
            .folder(dev),
        ])
        let cBar = BookmarkFolder(id: BookmarkID("c.bar"), title: "Barre", children: [bookmark("c.hn", "Hacker News", "https://news.ycombinator.com")])
        return (
            BookmarkTree(browser: .safari, roots: [sBar], capturedAt: .distantPast),
            BookmarkTree(browser: .chrome, roots: [cBar], capturedAt: .distantPast)
        )
    }

    @Test("Groups additions by destination browser with the right counts")
    func groupsByDestination() {
        let t = trees()
        let model = SyncPreviewViewModel()
        model.computePreview((safari, t.safari), (chrome, t.chrome))

        #expect(model.isEmpty == false)
        #expect(model.totalChanges == 3)   // Apple + Swift → Chrome, Hacker News → Safari

        let toChrome = model.directions.first { $0.targetName == "Chrome — Perso" }
        let toSafari = model.directions.first { $0.targetName == "Safari" }
        #expect(toChrome?.additions.map(\.title).sorted() == ["Apple", "Swift"])
        #expect(toSafari?.additions.map(\.title) == ["Hacker News"])
    }

    @Test("Builds the full friendly origin path")
    func buildsOriginPath() {
        let t = trees()
        let model = SyncPreviewViewModel()
        model.computePreview((safari, t.safari), (chrome, t.chrome))

        let toChrome = model.directions.first { $0.targetName == "Chrome — Perso" }
        let swift = toChrome?.additions.first { $0.title == "Swift" }
        // Safari › (friendly) Barre des favoris › Dev
        #expect(swift?.originPath == "Safari › Barre des favoris › Dev")
        #expect(swift?.subtitle == "swift.org")
    }

    // MARK: - Apply (Safari → Chrome)

    private struct StubApplier: ChromeBookmarkApplying {
        let result: Result<BackupHandle, any Error>
        func apply(_ additions: [Bookmark], to location: BrowserLocation, now: Date) async throws -> BackupHandle {
            try result.get()
        }
    }

    private final class StubBackup: BookmarkBackup, @unchecked Sendable {
        private(set) var restored: [BackupHandle] = []
        func backup(_ location: BrowserLocation) async throws -> BackupHandle {
            BackupHandle(id: UUID(), browser: location.browser, createdAt: .distantPast, fileURL: location.fileURL)
        }
        func restore(_ handle: BackupHandle) async throws { restored.append(handle) }
        func backups(for browser: Browser) async throws -> [BackupHandle] { [] }
    }

    private func handle() -> BackupHandle {
        BackupHandle(id: UUID(), browser: .chrome, createdAt: .distantPast, fileURL: URL(fileURLWithPath: "/tmp/backup"))
    }

    private let chromeLocation = BrowserLocation(browser: .chrome, fileURL: URL(fileURLWithPath: "/tmp/Chrome/Profile 1/Bookmarks"))

    @Test("Applies the Safari → Chrome additions via the applier")
    func appliesToChrome() async {
        let t = trees()
        let model = SyncPreviewViewModel(applier: StubApplier(result: .success(handle())))
        model.computePreview((safari, t.safari), (chrome, t.chrome), chromeWritableLocation: chromeLocation)

        #expect(model.canApplyToChrome)
        #expect(model.chromeAdditionsCount == 2)   // Apple + Swift
        await model.apply()
        #expect(model.applyState == .applied(count: 2))
    }

    @Test("Reports a clear message when Chrome is running")
    func failsWhenChromeRunning() async {
        let t = trees()
        let model = SyncPreviewViewModel(applier: StubApplier(result: .failure(ChromeWriteError.browserIsRunning)))
        model.computePreview((safari, t.safari), (chrome, t.chrome), chromeWritableLocation: chromeLocation)

        await model.apply()
        #expect(model.applyState == .failed("Ferme Google Chrome avant d'appliquer."))
    }

    @Test("Cannot apply without a writable Chrome target")
    func noApplyWithoutWritableTarget() async {
        let t = trees()
        let model = SyncPreviewViewModel(applier: StubApplier(result: .success(handle())))
        model.computePreview((safari, t.safari), (chrome, t.chrome))   // no writable location

        #expect(model.canApplyToChrome == false)
        await model.apply()
        #expect(model.applyState == .idle)   // no-op
    }

    @Test("Restore undoes an apply via the backup")
    func restoreUndoes() async {
        let t = trees()
        let backupStore = StubBackup()
        let applied = handle()
        let model = SyncPreviewViewModel(applier: StubApplier(result: .success(applied)), backup: backupStore)
        model.computePreview((safari, t.safari), (chrome, t.chrome), chromeWritableLocation: chromeLocation)

        await model.apply()
        await model.restore()
        #expect(backupStore.restored == [applied])
        #expect(model.applyState == .idle)
    }

    @Test("Identical sources preview as empty (no directions)")
    func emptyWhenIdentical() {
        let dev = BookmarkFolder(id: BookmarkID("x"), title: "X", children: [bookmark("a", "Apple", "https://apple.com")])
        let safariTree = BookmarkTree(browser: .safari, roots: [dev], capturedAt: .distantPast)
        let chromeTree = BookmarkTree(browser: .chrome, roots: [dev], capturedAt: .distantPast)

        let model = SyncPreviewViewModel()
        model.computePreview((safari, safariTree), (chrome, chromeTree))

        #expect(model.isEmpty)
        #expect(model.directions.isEmpty)
        #expect(model.totalChanges == 0)
    }
}
