//
//  DiagnosticFileFingerprint.swift
//  BookmarkBridge
//

import CryptoKit
import Foundation

/// Read-only content and file-identity evidence attached to diagnostics.
nonisolated struct DiagnosticFileFingerprint: Hashable, Sendable {
    let contentDigest: Data
    let fileSize: UInt64
    let modificationDate: Date
    let fileSystemNumber: UInt64
    let fileNumber: UInt64

    static func capture(at fileURL: URL) throws -> DiagnosticFileFingerprint {
        let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        let attributes = try FileManager.default.attributesOfItem(
            atPath: fileURL.path(percentEncoded: false)
        )
        guard let fileSize = (attributes[.size] as? NSNumber)?.uint64Value,
              let modificationDate = attributes[.modificationDate] as? Date,
              let fileSystemNumber =
                (attributes[.systemNumber] as? NSNumber)?.uint64Value,
              let fileNumber =
                (attributes[.systemFileNumber] as? NSNumber)?.uint64Value,
              fileSize == data.count else {
            throw DiagnosticFileFingerprintError.inconsistentAttributes
        }
        return DiagnosticFileFingerprint(
            contentDigest: Data(SHA256.hash(data: data)),
            fileSize: fileSize,
            modificationDate: modificationDate,
            fileSystemNumber: fileSystemNumber,
            fileNumber: fileNumber
        )
    }
}

nonisolated private enum DiagnosticFileFingerprintError: Error {
    case inconsistentAttributes
}
