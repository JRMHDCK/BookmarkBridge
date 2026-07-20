//
//  SafariBookmarkDocument.swift
//  BookmarkBridge
//

import Foundation

nonisolated enum SafariPropertyListFormat: Hashable, Sendable {
    case binary
    case xml
    case openStep
}

/// Immutable plist payload plus the fingerprint of the source it was read from.
/// Keeping the original bytes guarantees that unknown keys, UUIDs, metadata and
/// Foundation property-list value types survive persistence unchanged.
nonisolated struct SafariBookmarkDocument: Hashable, Sendable {
    let data: Data
    let format: SafariPropertyListFormat
    let sourceFingerprint: SafariDocumentFingerprint

    init(data: Data, sourceFingerprint: SafariDocumentFingerprint) throws {
        var propertyListFormat = PropertyListSerialization.PropertyListFormat.binary
        do {
            _ = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: &propertyListFormat
            )
        } catch {
            throw SafariPersistenceError.invalidPropertyList
        }

        self.data = data
        self.format = try SafariPropertyListFormat(propertyListFormat)
        self.sourceFingerprint = sourceFingerprint
    }
}

private nonisolated extension SafariPropertyListFormat {
    init(_ format: PropertyListSerialization.PropertyListFormat) throws {
        switch format {
        case .binary:
            self = .binary
        case .xml:
            self = .xml
        case .openStep:
            self = .openStep
        @unknown default:
            throw SafariPersistenceError.invalidPropertyList
        }
    }
}
