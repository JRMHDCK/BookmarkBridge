//
//  SyncPreviewViewModel.swift
//  BookmarkBridge
//

import Foundation
import Observation

/// Presentation state for the dry-run preview. It only orchestrates: it asks the
/// `BookmarkSyncPlanner` for a `SyncPreview` and maps it to display rows. No
/// matching/ranking logic lives here, and nothing is ever written.
@MainActor
@Observable
final class SyncPreviewViewModel {

    /// A single bookmark that would be added to one side.
    struct Addition: Identifiable {
        let id: String
        let title: String
        let subtitle: String?
        /// Full origin path, e.g. "Safari › Barre des favoris › Dev".
        let originPath: String
    }

    /// The additions heading to one target browser.
    struct Direction: Identifiable {
        let id: String
        let targetName: String
        let additions: [Addition]
    }

    /// State of the (Safari → Chrome) apply action.
    enum ApplyState: Equatable {
        case idle
        case applying
        case applied(count: Int)
        case restoring
        case restored
        case failed(String)
    }

    private(set) var directions: [Direction] = []
    private(set) var totalChanges = 0
    private(set) var isEmpty = true

    private(set) var applyState: ApplyState = .idle
    /// The writable Chrome target's display name, when writing is possible.
    private(set) var chromeTargetName: String?

    private let planner: BookmarkSyncPlanner
    private let applier: (any ChromeBookmarkApplying)?
    private let backup: (any BookmarkBackup)?
    private let browserDetector: (any RunningBrowserDetecting)?
    private let fileController: any SecurityScopedFileControlling

    /// Set when a preview is computed with a writable Chrome target.
    private var chromeLocation: BrowserLocation?
    /// The security-scoped Chrome directory to open while writing.
    private var chromeScopeDirectory: BrowserLocation?
    private var chromeAdditions: [Bookmark] = []
    private var backupHandlesBySource: [BookmarkSourceID: BackupHandle] = [:]

    init(
        planner: BookmarkSyncPlanner = BookmarkSyncPlanner(),
        applier: (any ChromeBookmarkApplying)? = nil,
        backup: (any BookmarkBackup)? = nil,
        browserDetector: (any RunningBrowserDetecting)? = nil,
        fileController: any SecurityScopedFileControlling = SystemSecurityScopedFileController()
    ) {
        self.planner = planner
        self.applier = applier
        self.backup = backup
        self.browserDetector = browserDetector
        self.fileController = fileController
    }

    /// Whether the Safari → Chrome additions can be written (a writable Chrome
    /// target with at least one addition and an applier available).
    var canApplyToChrome: Bool {
        !isBusy && applier != nil && chromeLocation != nil && !chromeAdditions.isEmpty
    }

    /// Number of bookmarks that would be added to Chrome.
    var chromeAdditionsCount: Int { chromeAdditions.count }

    /// True only when a real pre-write backup handle is available.
    var canRestore: Bool {
        guard let selectedChromeID else { return false }
        return backup != nil && browserDetector != nil && backupHandlesBySource[selectedChromeID] != nil
    }

    var isBusy: Bool {
        applyState == .applying || applyState == .restoring
    }

    var canRetry: Bool {
        guard case .failed = applyState else { return false }
        return !canRestore && applier != nil && chromeLocation != nil && !chromeAdditions.isEmpty
    }

    /// True when the selected Chrome profile can be previewed but not written in
    /// V1 (account or ambiguous storage) — used to explain why Apply is disabled.
    var selectedChromeIsReadOnly: Bool {
        guard let candidate = chromeCandidates.first(where: { $0.id == selectedChromeID }) else { return false }
        return candidate.writable == nil
    }

    // MARK: - Chrome target selection

    /// A candidate Chrome profile the user can sync toward.
    struct ChromeCandidate: Identifiable {
        let source: BookmarkSource
        let tree: BookmarkTree
        let writable: BrowserLocation?
        /// The security-scoped Chrome directory to open while writing `writable`.
        let scope: BrowserLocation?
        var id: BookmarkSourceID { source.id }
    }

    private(set) var chromeCandidates: [ChromeCandidate] = []
    private var safariPair: (source: BookmarkSource, tree: BookmarkTree)?

    /// The selected Chrome target; changing it recomputes the preview.
    var selectedChromeID: BookmarkSourceID? {
        didSet {
            guard oldValue != selectedChromeID else { return }
            recomputeForSelection()
        }
    }

    /// Sets up the preview for Safari ↔ one of several Chrome profiles, selecting
    /// the first by default.
    func configure(safari: (source: BookmarkSource, tree: BookmarkTree), chromeCandidates: [ChromeCandidate]) {
        self.safariPair = safari
        self.chromeCandidates = chromeCandidates
        self.selectedChromeID = chromeCandidates.first?.id
        recomputeForSelection()
    }

    private func recomputeForSelection() {
        guard let safariPair,
              let candidate = chromeCandidates.first(where: { $0.id == selectedChromeID }) else { return }
        computePreview(
            safariPair,
            (candidate.source, candidate.tree),
            chromeWritableLocation: candidate.writable,
            chromeScopeDirectory: candidate.scope
        )
    }

    /// Replaces the selected profile with the tree just re-read from disk and
    /// recomputes the preview without discarding the successful write's backup.
    func updateSelectedChromeTree(_ tree: BookmarkTree) {
        guard let selectedChromeID,
              let index = chromeCandidates.firstIndex(where: { $0.id == selectedChromeID }) else { return }
        let candidate = chromeCandidates[index]
        let previousApplyState = applyState
        chromeCandidates[index] = ChromeCandidate(
            source: candidate.source,
            tree: tree,
            writable: candidate.writable,
            scope: candidate.scope
        )
        recomputeForSelection()
        applyState = previousApplyState
    }

    /// Computes the read-only preview between two loaded sources. Pass the Chrome
    /// profile's writable location (from `DashboardViewModel.writableLocation`)
    /// to enable the Safari → Chrome apply action.
    func computePreview(
        _ a: (source: BookmarkSource, tree: BookmarkTree),
        _ b: (source: BookmarkSource, tree: BookmarkTree),
        chromeWritableLocation: BrowserLocation? = nil,
        chromeScopeDirectory: BrowserLocation? = nil
    ) {
        let preview = planner.preview(between: a.tree, and: b.tree)
        totalChanges = preview.totalChanges
        isEmpty = preview.isEmpty
        applyState = .idle

        let names: [Browser: String] = [
            a.source.browser: a.source.displayName,
            b.source.browser: b.source.displayName,
        ]

        directions = preview.plans.compactMap { plan in
            let additions = plan.changes.compactMap { change in Self.addition(from: change, sourceBrowser: plan.source, names: names) }
            guard !additions.isEmpty else { return nil }
            return Direction(
                id: plan.target.rawValue,
                targetName: names[plan.target] ?? plan.target.displayName,
                additions: additions
            )
        }

        // Prepare the Safari → Chrome apply (only the bookmarks to add to Chrome).
        chromeLocation = chromeWritableLocation
        self.chromeScopeDirectory = chromeScopeDirectory
        chromeTargetName = names[.chrome]
        chromeAdditions = (preview.plan(addingTo: .chrome)?.changes ?? []).compactMap { change in
            if case .add(let node, _, _) = change, case .bookmark(let bookmark) = node { bookmark } else { nil }
        }
    }

    /// Applies the Safari → Chrome additions using the validated write chain
    /// (`ChromeBookmarkApplier`: Chrome-closed check, mandatory backup, atomic
    /// write, reversible). Does nothing if applying is not possible.
    func apply(now: Date = Date()) async {
        guard let applier,
              let location = chromeLocation,
              let scope = chromeScopeDirectory,
              !chromeAdditions.isEmpty else { return }
        applyState = .applying
        do {
            let result = try await applier.apply(chromeAdditions, to: location, in: scope, now: now)
            if let selectedChromeID {
                backupHandlesBySource[selectedChromeID] = result.backup
            }
            applyState = .applied(count: result.addedCount)
        } catch ChromeWriteError.browserIsRunning {
            applyState = .failed(
                DocumentationText.value("sync.closeBrowsers.error")
            )
        } catch ChromeWriteError.browserStartedDuringTransaction(let handle) {
            if let selectedChromeID {
                backupHandlesBySource[selectedChromeID] = handle
            }
            applyState = .failed(
                DocumentationText.value("sync.closeBrowsers.error")
            )
        } catch ChromeWriteError.bakCreationFailed(let handle, _) {
            if let selectedChromeID {
                backupHandlesBySource[selectedChromeID] = handle
            }
            applyState = .failed(
                DocumentationText.value("sync.backupBak.failure")
            )
        } catch ChromeWriteError.transactionFailed(let handle, _) {
            if let selectedChromeID {
                backupHandlesBySource[selectedChromeID] = handle
            }
            applyState = .failed(
                DocumentationText.value("sync.chromeUpdate.failure")
            )
        } catch ChromeWriteError.backupFailed {
            applyState = .failed(
                DocumentationText.value("sync.backup.failure")
            )
        } catch ChromeWriteError.securityScopeDenied {
            applyState = .failed(
                DocumentationText.value("sync.chromeWriteAccess.failure")
            )
        } catch {
            applyState = .failed(
                DocumentationText.value("sync.failure.short")
            )
        }
    }

    /// Reloads the latest on-disk backup for the selected Chrome profile.
    func refreshAvailableBackup() async {
        guard let backup,
              let selectedChromeID,
              let location = chromeLocation,
              backupHandlesBySource[selectedChromeID] == nil else { return }
        do {
            backupHandlesBySource[selectedChromeID] = try await backup.backups(for: location).first
        } catch {
            // Backup discovery is non-destructive; an unavailable listing simply
            // leaves restoration disabled until a real handle can be loaded.
        }
    }

    func prepareRetry() {
        guard canRetry else { return }
        applyState = .idle
    }

    /// Restores the pre-write state from the last apply's backup.
    func restore() async {
        guard let backup,
              let browserDetector,
              let selectedChromeID,
              let handle = backupHandlesBySource[selectedChromeID],
              let scope = chromeScopeDirectory else { return }
        guard !browserDetector.isRunning(.chrome) else {
            applyState = .failed(
                DocumentationText.value("sync.closeBrowsers.error")
            )
            return
        }
        applyState = .restoring
        let scopeURL = scope.fileURL
        let accessing = fileController.startAccessing(scopeURL)
        guard accessing else {
            applyState = .failed(
                DocumentationText.value("sync.chromeWriteAccess.failure")
            )
            return
        }
        defer { fileController.stopAccessing(scopeURL) }
        do {
            try await backup.restore(handle)
            backupHandlesBySource[selectedChromeID] = nil
            applyState = .restored
        } catch {
            applyState = .failed(
                DocumentationText.value("restore.failure.short")
            )
        }
    }

    private static func addition(from change: SyncChange, sourceBrowser: Browser, names: [Browser: String]) -> Addition? {
        guard case .add(let node, _, let sourcePath) = change, case .bookmark(let bookmark) = node else {
            return nil
        }
        let sourceName = names[sourceBrowser] ?? sourceBrowser.displayName
        let origin = ([sourceName] + sourcePath.map { FolderTitleFormatter.friendly($0.title) })
            .joined(separator: " › ")
        return Addition(
            id: "\(sourceBrowser.rawValue)|\(bookmark.id.rawValue)",
            title: bookmark.title.isEmpty
                ? DocumentationText.value("bookmark.untitled.parenthesized")
                : bookmark.title,
            subtitle: bookmark.url.host() ?? bookmark.url.absoluteString,
            originPath: origin
        )
    }
}
