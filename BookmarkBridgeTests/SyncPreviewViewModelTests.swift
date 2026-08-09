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
        let bookmarksBar = DocumentationText.value("folder.bookmarksBar")
        #expect(swift?.originPath == "Safari › \(bookmarksBar) › Dev")
        #expect(swift?.subtitle == "swift.org")
    }

    // MARK: - Apply (Safari → Chrome)

    private struct StubApplier: ChromeBookmarkApplying {
        let result: Result<ChromeApplyResult, any Error>
        func apply(_ additions: [Bookmark], to location: BrowserLocation, in scopeDirectory: BrowserLocation, now: Date) async throws -> ChromeApplyResult {
            try result.get()
        }
    }

    private struct StubDetector: RunningBrowserDetecting {
        let isChromeRunning: Bool
        func isRunning(_ browser: Browser) -> Bool { isChromeRunning }
    }

    private final class StubBackup: BookmarkBackup, @unchecked Sendable {
        private(set) var restored: [BackupHandle] = []
        var available: [BackupHandle] = []
        private(set) var requestedLocations: [BrowserLocation] = []
        func backup(_ location: BrowserLocation) async throws -> BackupHandle {
            BackupHandle(id: UUID(), browser: location.browser, createdAt: .distantPast, fileURL: location.fileURL)
        }
        func restore(_ handle: BackupHandle) async throws { restored.append(handle) }
        func backups(for browser: Browser) async throws -> [BackupHandle] { [] }
        func backups(for location: BrowserLocation) async throws -> [BackupHandle] {
            requestedLocations.append(location)
            return available
        }
    }

    private func handle() -> BackupHandle {
        BackupHandle(id: UUID(), browser: .chrome, createdAt: .distantPast, fileURL: URL(fileURLWithPath: "/tmp/backup"))
    }


    private func applyResult(addedCount: Int = 2, backup: BackupHandle? = nil) -> ChromeApplyResult {
        ChromeApplyResult(backup: backup ?? handle(), addedCount: addedCount)
    }

    private let chromeLocation = BrowserLocation(browser: .chrome, fileURL: URL(fileURLWithPath: "/tmp/Chrome/Profile 1/Bookmarks"))
    private let chromeScope = BrowserLocation(browser: .chrome, fileURL: URL(fileURLWithPath: "/tmp/Chrome/Profile 1"))

    @Test("Applies the Safari → Chrome additions via the applier")
    func appliesToChrome() async {
        let t = trees()
        let model = SyncPreviewViewModel(
            applier: StubApplier(result: .success(applyResult())),
            backup: StubBackup(),
            browserDetector: StubDetector(isChromeRunning: false)
        )
        model.configure(safari: (safari, t.safari), chromeCandidates: [
            .init(source: chrome, tree: t.chrome, writable: chromeLocation, scope: chromeScope),
        ])

        #expect(model.canApplyToChrome)
        #expect(model.chromeAdditionsCount == 2)   // Apple + Swift
        await model.apply()
        #expect(model.applyState == .applied(count: 2))
        #expect(model.canRestore)
    }

    @Test("Reloading Chrome after apply immediately empties the preview")
    func reloadAfterApplyEmptiesPreview() async {
        let safariBar = BookmarkFolder(id: BookmarkID("s.bar"), title: "BookmarksBar", children: [
            bookmark("s.ap", "Apple", "https://apple.com"),
        ])
        let emptyChromeBar = BookmarkFolder(id: BookmarkID("c.bar"), title: "Barre", children: [])
        let refreshedChromeBar = BookmarkFolder(id: BookmarkID("c.bar"), title: "Barre", children: [
            bookmark("c.ap", "Apple", "https://apple.com/"),
        ])
        let safariTree = BookmarkTree(browser: .safari, roots: [safariBar], capturedAt: .distantPast)
        let initialChromeTree = BookmarkTree(browser: .chrome, roots: [emptyChromeBar], capturedAt: .distantPast)
        let refreshedChromeTree = BookmarkTree(browser: .chrome, roots: [refreshedChromeBar], capturedAt: .now)
        let model = SyncPreviewViewModel(
            applier: StubApplier(result: .success(applyResult(addedCount: 1))),
            backup: StubBackup(),
            browserDetector: StubDetector(isChromeRunning: false)
        )
        model.configure(safari: (safari, safariTree), chromeCandidates: [
            .init(source: chrome, tree: initialChromeTree, writable: chromeLocation, scope: chromeScope),
        ])

        await model.apply()
        model.updateSelectedChromeTree(refreshedChromeTree)

        #expect(model.isEmpty)
        #expect(model.totalChanges == 0)
        #expect(model.directions.isEmpty)
        #expect(model.chromeAdditionsCount == 0)
        #expect(model.canRestore)
    }

    @Test("Reports a clear message when Chrome is running")
    func failsWhenChromeRunning() async {
        let t = trees()
        let model = SyncPreviewViewModel(applier: StubApplier(result: .failure(ChromeWriteError.browserIsRunning)))
        model.configure(safari: (safari, t.safari), chromeCandidates: [
            .init(source: chrome, tree: t.chrome, writable: chromeLocation, scope: chromeScope),
        ])

        await model.apply()
        #expect(
            model.applyState
                == .failed("Safari et Chrome doivent être fermés.")
        )
        #expect(model.canRetry)
        #expect(model.canRestore == false)

        model.prepareRetry()
        #expect(model.applyState == .idle)
    }

    @Test("Retains the backup if Chrome starts before the final replacement")
    func retainsBackupWhenChromeStartsDuringTransaction() async {
        let t = trees()
        let retained = handle()
        let model = SyncPreviewViewModel(
            applier: StubApplier(result: .failure(
                ChromeWriteError.browserStartedDuringTransaction(backup: retained)
            )),
            backup: StubBackup(),
            browserDetector: StubDetector(isChromeRunning: false)
        )
        model.configure(safari: (safari, t.safari), chromeCandidates: [
            .init(source: chrome, tree: t.chrome, writable: chromeLocation, scope: chromeScope),
        ])

        await model.apply()

        #expect(
            model.applyState
                == .failed("Safari et Chrome doivent être fermés.")
        )
        #expect(model.canRestore)
    }

    @Test("Cannot apply without a writable Chrome target")
    func noApplyWithoutWritableTarget() async {
        let t = trees()
        let model = SyncPreviewViewModel(applier: StubApplier(result: .success(applyResult())))
        model.computePreview((safari, t.safari), (chrome, t.chrome))   // no writable location

        #expect(model.canApplyToChrome == false)
        await model.apply()
        #expect(model.applyState == .idle)   // no-op
    }

    @Test("Restore undoes an apply via the backup")
    func restoreUndoes() async {
        let t = trees()
        let backupStore = StubBackup()
        let controller = SpySecurityScopedFileController()
        let applied = handle()
        let model = SyncPreviewViewModel(
            applier: StubApplier(result: .success(applyResult(backup: applied))),
            backup: backupStore,
            browserDetector: StubDetector(isChromeRunning: false),
            fileController: controller
        )
        model.configure(safari: (safari, t.safari), chromeCandidates: [
            .init(source: chrome, tree: t.chrome, writable: chromeLocation, scope: chromeScope),
        ])

        await model.apply()
        await model.restore()
        #expect(backupStore.restored == [applied])
        #expect(model.applyState == .restored)
        #expect(model.canRestore == false)
        #expect(controller.startCount == 1)
        #expect(controller.stopCount == 1)
    }

    @Test("Restore is refused while Chrome is running")
    func restoreRefusesWhenChromeIsRunning() async {
        let t = trees()
        let backupStore = StubBackup()
        let controller = SpySecurityScopedFileController()
        let applied = handle()
        let model = SyncPreviewViewModel(
            applier: StubApplier(result: .success(applyResult(backup: applied))),
            backup: backupStore,
            browserDetector: StubDetector(isChromeRunning: true),
            fileController: controller
        )
        model.configure(safari: (safari, t.safari), chromeCandidates: [
            .init(source: chrome, tree: t.chrome, writable: chromeLocation, scope: chromeScope),
        ])

        await model.apply()
        await model.restore()

        #expect(
            model.applyState
                == .failed("Safari et Chrome doivent être fermés.")
        )
        #expect(model.canRestore)
        #expect(backupStore.restored.isEmpty)
        #expect(controller.startCount == 0)
    }

    @Test("Restore is refused when the security scope cannot be opened")
    func restoreRefusesDeniedScope() async {
        let t = trees()
        let backupStore = StubBackup()
        let controller = SpySecurityScopedFileController()
        controller.startReturnValue = false
        let applied = handle()
        let model = SyncPreviewViewModel(
            applier: StubApplier(result: .success(applyResult(backup: applied))),
            backup: backupStore,
            browserDetector: StubDetector(isChromeRunning: false),
            fileController: controller
        )
        model.configure(safari: (safari, t.safari), chromeCandidates: [
            .init(source: chrome, tree: t.chrome, writable: chromeLocation, scope: chromeScope),
        ])

        await model.apply()
        await model.restore()

        #expect(
            model.applyState == .failed(
                DocumentationText.value("sync.chromeWriteAccess.failure")
            )
        )
        #expect(model.canRestore)
        #expect(backupStore.restored.isEmpty)
        #expect(controller.startCount == 1)
        #expect(controller.stopCount == 0)
    }

    @Test("A new preview model reloads the persisted backup for the selected profile")
    func reloadsPersistedBackupAfterReopening() async {
        let t = trees()
        let backupStore = StubBackup()
        backupStore.available = [handle()]
        let reopenedModel = SyncPreviewViewModel(
            backup: backupStore,
            browserDetector: StubDetector(isChromeRunning: false)
        )
        reopenedModel.configure(safari: (safari, t.safari), chromeCandidates: [
            .init(source: chrome, tree: t.chrome, writable: chromeLocation, scope: chromeScope),
        ])

        #expect(reopenedModel.canRestore == false)
        await reopenedModel.refreshAvailableBackup()

        #expect(reopenedModel.canRestore)
        #expect(backupStore.requestedLocations == [chromeLocation])
    }

    @Test("Apply displays the number actually added by the writer")
    func displaysActualAddedCount() async {
        let t = trees()
        let model = SyncPreviewViewModel(applier: StubApplier(result: .success(applyResult(addedCount: 1))))
        model.configure(safari: (safari, t.safari), chromeCandidates: [
            .init(source: chrome, tree: t.chrome, writable: chromeLocation, scope: chromeScope),
        ])

        #expect(model.chromeAdditionsCount == 2)
        await model.apply()

        #expect(model.applyState == .applied(count: 1))
    }

    @Test("A failed transaction retains its real backup for restoration")
    func failedTransactionRetainsBackup() async {
        let t = trees()
        let backupStore = StubBackup()
        let controller = SpySecurityScopedFileController()
        let retained = handle()
        let underlying = NSError(domain: "BookmarkBridgeTests", code: 42, userInfo: [
            NSLocalizedDescriptionKey: "Synthetic write failure",
        ])
        let diagnostic = ChromeWriteDiagnostic(stage: "remplacement atomique", error: underlying)
        let model = SyncPreviewViewModel(
            applier: StubApplier(result: .failure(ChromeWriteError.transactionFailed(backup: retained, diagnostic: diagnostic))),
            backup: backupStore,
            browserDetector: StubDetector(isChromeRunning: false),
            fileController: controller
        )
        model.configure(safari: (safari, t.safari), chromeCandidates: [
            .init(source: chrome, tree: t.chrome, writable: chromeLocation, scope: chromeScope),
        ])

        await model.apply()
        #expect(model.applyState == .failed("Impossible de mettre à jour les favoris Chrome."))
        #expect(model.canRestore)

        await model.restore()
        #expect(backupStore.restored == [retained])
        #expect(controller.startCount == 1)
        #expect(controller.stopCount == 1)
    }

    @Test("Selecting a Chrome target recomputes the preview for that profile")
    func selectsChromeTarget() {
        let t = trees()
        let chromeB = BookmarkSource(browser: .chrome, profile: "Profile 2", displayName: "Chrome — Test")
        // chromeB already contains Safari's bookmarks → nothing to add to it.
        let bBar = BookmarkFolder(id: BookmarkID("b.bar"), title: "Barre", children: [
            bookmark("b.ap", "Apple", "https://apple.com"),
            bookmark("b.sw", "Swift", "https://swift.org"),
        ])
        let bTree = BookmarkTree(browser: .chrome, roots: [bBar], capturedAt: .distantPast)

        let model = SyncPreviewViewModel()
        model.configure(safari: (safari, t.safari), chromeCandidates: [
            .init(source: chrome, tree: t.chrome, writable: nil, scope: nil),   // has only Hacker News
            .init(source: chromeB, tree: bTree, writable: nil, scope: nil),     // already has Apple + Swift
        ])

        #expect(model.chromeCandidates.count == 2)
        #expect(model.selectedChromeID == chrome.id)     // first selected by default
        #expect(model.chromeAdditionsCount == 2)         // Apple + Swift → Chrome — Perso

        model.selectedChromeID = chromeB.id
        #expect(model.chromeAdditionsCount == 0)         // Chrome — Test already has them
    }

    @Test("A read-only Chrome target is flagged and cannot be applied")
    func readOnlyTargetFlagged() {
        let t = trees()
        let account = BookmarkSource(browser: .chrome, profile: "Profile 2", displayName: "Chrome — Test")
        let model = SyncPreviewViewModel(applier: StubApplier(result: .success(applyResult())))
        model.configure(safari: (safari, t.safari), chromeCandidates: [
            .init(source: account, tree: t.chrome, writable: nil, scope: nil),   // no writable location
        ])
        #expect(model.selectedChromeIsReadOnly)
        #expect(model.canApplyToChrome == false)
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
