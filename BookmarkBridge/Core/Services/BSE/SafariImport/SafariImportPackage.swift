//
//  SafariImportPackage.swift
//  BookmarkBridge
//

import Foundation

/// An HTML artifact prepared for Safari's supported bookmark import workflow.
/// It never points at Safari's private bookmark database.
nonisolated struct SafariImportPackage: Hashable, Sendable {
    let fileURL: URL
    let byteCount: Int
    let sha256: Data
    let folderCount: Int
    let bookmarkCount: Int
    let skippedBookmarks: [SafariImportSkippedBookmark]
    let compatibility: SafariImportCompatibilityReport
}

nonisolated struct SafariImportSkippedBookmark: Hashable, Sendable {
    let bookmarkID: BookmarkID
    let title: String
    let url: URL
    let reason: SafariImportIncompatibilityReason
}

nonisolated enum SafariImportPackageError: Error, Hashable, Sendable {
    case incompatiblePlan(SafariImportCompatibilityReport)
    case invalidFileName
    case cannotCreateDirectory
    case cannotWriteFile
}
