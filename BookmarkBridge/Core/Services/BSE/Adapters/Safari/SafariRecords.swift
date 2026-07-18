//
//  SafariRecords.swift
//  BookmarkBridge
//

import Foundation

/// Deterministic snapshot-local location within the extracted hierarchy.
nonisolated struct SafariRecordPath: Hashable, Codable, Sendable {
    let positions: [Int]

    init(_ positions: [Int]) {
        self.positions = positions
    }
}

/// Internal representation of a Safari bookmark before BSE conversion.
nonisolated struct SafariBookmarkRecord: Hashable, Sendable {
    let nativeIdentifier: String?
    let title: String?
    let urlString: String?
    let position: Int
    let path: SafariRecordPath

    init(
        nativeIdentifier: String?,
        title: String?,
        urlString: String?,
        position: Int,
        path: SafariRecordPath
    ) {
        self.nativeIdentifier = nativeIdentifier
        self.title = title
        self.urlString = urlString
        self.position = position
        self.path = path
    }
}

/// Internal representation of a Safari folder before BSE conversion.
nonisolated struct SafariFolderRecord: Hashable, Sendable {
    let nativeIdentifier: String?
    let title: String?
    let position: Int
    let path: SafariRecordPath
    let children: [SafariRecord]

    init(
        nativeIdentifier: String?,
        title: String?,
        position: Int,
        path: SafariRecordPath,
        children: [SafariRecord]
    ) {
        self.nativeIdentifier = nativeIdentifier
        self.title = title
        self.position = position
        self.path = path
        self.children = children
    }
}

/// Internal, ordered native hierarchy extracted from Safari.
nonisolated indirect enum SafariRecord: Hashable, Sendable {
    case bookmark(SafariBookmarkRecord)
    case folder(SafariFolderRecord)

    var path: SafariRecordPath {
        switch self {
        case .bookmark(let record): record.path
        case .folder(let record): record.path
        }
    }
}

/// Source metadata and native records captured during one coherent read.
nonisolated struct SafariExtraction: Hashable, Sendable {
    let records: [SafariRecord]
    let capturedAt: Date
    let safariVersion: String?
    let storageVersion: String?
    let issues: [SafariReadIssue]

    init(
        records: [SafariRecord],
        capturedAt: Date,
        safariVersion: String?,
        storageVersion: String?,
        issues: [SafariReadIssue]
    ) {
        self.records = records
        self.capturedAt = capturedAt
        self.safariVersion = safariVersion
        self.storageVersion = storageVersion
        self.issues = issues
    }
}
