//
//  ChromeRecords.swift
//  BookmarkBridge
//

import Foundation

nonisolated enum ChromeProfileIdentifierError: Error, Hashable, Sendable {
    case empty
    case pathSeparator
    case reservedComponent
}

/// Explicit identifier of one local Chrome profile directory.
nonisolated struct ChromeProfileIdentifier: Hashable, Codable, Sendable {
    let rawValue: String

    init(_ rawValue: String) throws {
        guard !rawValue.isEmpty else {
            throw ChromeProfileIdentifierError.empty
        }
        guard !rawValue.contains("/"), !rawValue.contains(":") else {
            throw ChromeProfileIdentifierError.pathSeparator
        }
        guard rawValue != ".", rawValue != ".." else {
            throw ChromeProfileIdentifierError.reservedComponent
        }
        self.rawValue = rawValue
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        do {
            try self.init(value)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid Chrome profile identifier"
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Chrome roots are ordered explicitly so JSON dictionary order is irrelevant.
nonisolated enum ChromeRootKind: String, CaseIterable, Hashable, Codable, Sendable {
    case bookmarksBar
    case otherBookmarks
    case mobileBookmarks

    var permanentRootRole: PermanentRootRole {
        switch self {
        case .bookmarksBar:
            .primaryBookmarks
        case .otherBookmarks:
            .secondaryBookmarks
        case .mobileBookmarks:
            .mobileBookmarks
        }
    }
}

/// Deterministic snapshot-local location within one extracted profile.
nonisolated struct ChromeRecordPath: Hashable, Codable, Sendable {
    let root: ChromeRootKind
    let positions: [Int]

    init(root: ChromeRootKind, positions: [Int] = []) {
        self.root = root
        self.positions = positions
    }
}

nonisolated struct ChromeBookmarkRecord: Hashable, Sendable {
    let chromeID: String?
    let chromeGUID: String?
    let title: String?
    let urlString: String?
    let position: Int
    let path: ChromeRecordPath
}

nonisolated struct ChromeFolderRecord: Hashable, Sendable {
    let chromeID: String?
    let chromeGUID: String?
    let title: String?
    let position: Int
    let path: ChromeRecordPath
    let children: [ChromeRecord]
}

nonisolated indirect enum ChromeRecord: Hashable, Sendable {
    case bookmark(ChromeBookmarkRecord)
    case folder(ChromeFolderRecord)
}

/// Native records and metadata captured during one coherent profile read.
nonisolated struct ChromeExtraction: Hashable, Sendable {
    let records: [ChromeRecord]
    let capturedAt: Date
    let chromeVersion: String?
    let storageVersion: String?
    let profileIdentifier: ChromeProfileIdentifier
    let issues: [ChromeReadIssue]
}
