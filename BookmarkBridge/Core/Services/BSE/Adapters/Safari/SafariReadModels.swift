//
//  SafariReadModels.swift
//  BookmarkBridge
//

import Foundation

/// A local anomaly tied to one deterministic position in the Safari hierarchy.
/// No caller needs to parse text to distinguish issue kinds.
nonisolated enum SafariReadIssue: Hashable, Codable, Sendable {
    case missingTitle(path: SafariRecordPath)
    case missingURL(path: SafariRecordPath)
    case invalidURL(path: SafariRecordPath)
    case unsupportedNode(path: SafariRecordPath)
    case duplicateNativeIdentifier(path: SafariRecordPath)
    case missingNativeIdentifier(path: SafariRecordPath)
    case unknownNodeType(path: SafariRecordPath)
}

/// Global failures that prevent construction of one coherent BSE snapshot.
nonisolated enum SafariReadError: Error, Hashable, Sendable {
    case storageUnavailable
    case storageCorrupted
    case permissionDenied
    case snapshotInconsistent
    case unsupportedStorageVersion(String?)
    case readFailure
}

/// Diagnostic metrics for one read, deliberately independent of the snapshot.
nonisolated struct SafariReadReport: Hashable, Codable, Sendable {
    let foldersRead: Int
    let bookmarksRead: Int
    let issuesCount: Int
    let duration: TimeInterval
    let safariVersion: String?
    let storageVersion: String?

    init(
        foldersRead: Int,
        bookmarksRead: Int,
        issuesCount: Int,
        duration: TimeInterval,
        safariVersion: String?,
        storageVersion: String?
    ) {
        self.foldersRead = foldersRead
        self.bookmarksRead = bookmarksRead
        self.issuesCount = issuesCount
        self.duration = duration
        self.safariVersion = safariVersion
        self.storageVersion = storageVersion
    }
}

/// Full Safari-specific read result. `readSnapshot()` exposes only `snapshot`
/// through the universal adapter contract.
nonisolated struct SafariReadResult: Hashable, Sendable {
    let snapshot: BSESnapshot
    let report: SafariReadReport
    let issues: [SafariReadIssue]

    init(
        snapshot: BSESnapshot,
        report: SafariReadReport,
        issues: [SafariReadIssue]
    ) {
        self.snapshot = snapshot
        self.report = report
        self.issues = issues
    }
}
