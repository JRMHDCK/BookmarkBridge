//
//  SafariImportWorkflow.swift
//  BookmarkBridge
//

import Foundation

nonisolated struct SafariImportPresentation: Hashable, Sendable {
    let fileURL: URL
    let bookmarkCount: Int
    let folderCount: Int
    let skippedBookmarkCount: Int
    let unsupportedOperationCount: Int
    let sha256: Data
}

nonisolated enum SafariImportWorkflowError: Error, Hashable, Sendable {
    case invalidDirection
    case unsupportedSelection
    case noImportableChanges
}

nonisolated protocol SafariImportWorkflowPreparing: Sendable {
    func prepare(
        preview: SynchronizationPreviewResult
    ) async throws -> SafariImportPackage
}

/// Prepares a Safari-supported HTML import from creations in the exact plan
/// shown to the user. Existing Chrome nodes are intentionally excluded, and
/// Safari's private bookmark storage is never written.
nonisolated struct SafariImportWorkflow: SafariImportWorkflowPreparing {
    private let destinationDirectory: URL
    private let deltaTreeBuilder: SafariImportDeltaTreeBuilder
    private let packageBuilder: SafariImportPackageBuilder

    init(
        destinationDirectory: URL,
        deltaTreeBuilder: SafariImportDeltaTreeBuilder =
            SafariImportDeltaTreeBuilder(),
        packageBuilder: SafariImportPackageBuilder =
            SafariImportPackageBuilder()
    ) {
        self.destinationDirectory = destinationDirectory
        self.deltaTreeBuilder = deltaTreeBuilder
        self.packageBuilder = packageBuilder
    }

    func prepare(
        preview: SynchronizationPreviewResult
    ) async throws -> SafariImportPackage {
        guard preview.direction == .chromeToSafari else {
            throw SafariImportWorkflowError.invalidDirection
        }
        guard preview.request.chromeSelection == .all,
              preview.request.safariSelection == .all else {
            throw SafariImportWorkflowError.unsupportedSelection
        }

        let tree = deltaTreeBuilder.build(from: preview.plan)
        guard !tree.roots.isEmpty else {
            throw SafariImportWorkflowError.noImportableChanges
        }

        return try packageBuilder.build(
            tree: tree,
            plan: preview.plan,
            destinationDirectory: destinationDirectory,
            compatibilityPolicy: .allowAdditiveImport
        )
    }
}

nonisolated extension SafariImportPackage {
    var presentation: SafariImportPresentation {
        SafariImportPresentation(
            fileURL: fileURL,
            bookmarkCount: bookmarkCount,
            folderCount: folderCount,
            skippedBookmarkCount: skippedBookmarks.count,
            unsupportedOperationCount:
                compatibility.incompatibilities.count,
            sha256: sha256
        )
    }
}
