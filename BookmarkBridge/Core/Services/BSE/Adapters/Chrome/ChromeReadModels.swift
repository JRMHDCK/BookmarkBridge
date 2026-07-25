//
//  ChromeReadModels.swift
//  BookmarkBridge
//

import Foundation

/// A local anomaly tied to one deterministic position in a Chrome profile.
nonisolated enum ChromeReadIssue: Hashable, Codable, Sendable {
    case missingTitle(path: ChromeRecordPath)
    case missingURL(path: ChromeRecordPath)
    case invalidURL(path: ChromeRecordPath)
    case unsupportedNode(path: ChromeRecordPath)
    case duplicateNativeIdentifier(path: ChromeRecordPath)
    case missingNativeIdentifier(path: ChromeRecordPath)
    case invalidNativeIdentifier(
        path: ChromeRecordPath,
        reason: ChromeNativeIdentifierError
    )
    case unknownNodeType(path: ChromeRecordPath)
}

/// Global failures that prevent construction of one coherent BSE snapshot.
nonisolated enum ChromeReadError: Error, Hashable, Sendable {
    case storageUnavailable
    case storageCorrupted
    case permissionDenied
    case snapshotInconsistent
    case unsupportedStorageVersion(String?)
    case profileMismatch
    case readFailure
}

/// Diagnostic metrics for one profile read, independent of the snapshot.
nonisolated struct ChromeReadReport: Hashable, Codable, Sendable {
    let foldersRead: Int
    let bookmarksRead: Int
    let issuesCount: Int
    let duration: TimeInterval
    let chromeVersion: String?
    let storageVersion: String?
    let profileIdentifier: ChromeProfileIdentifier
}

/// Full Chrome-specific read result. The universal contract exposes its snapshot.
nonisolated struct ChromeReadResult: Hashable, Sendable {
    let snapshot: BSESnapshot
    let report: ChromeReadReport
    let issues: [ChromeReadIssue]
    let nativeIdentityObservations: [NativeIdentityObservation]
}
