//
//  ChromeDocumentFingerprint.swift
//  BookmarkBridge
//

import CryptoKit
import Foundation

/// Content and file-identity evidence used as an optimistic concurrency token.
nonisolated struct ChromeDocumentFingerprint: Hashable, Sendable {
    let contentDigest: Data
    let fileSize: UInt64
    let modificationDate: Date
    let fileSystemNumber: UInt64
    let fileNumber: UInt64

    init(
        contentDigest: Data,
        fileSize: UInt64,
        modificationDate: Date,
        fileSystemNumber: UInt64,
        fileNumber: UInt64
    ) {
        self.contentDigest = contentDigest
        self.fileSize = fileSize
        self.modificationDate = modificationDate
        self.fileSystemNumber = fileSystemNumber
        self.fileNumber = fileNumber
    }

    static func capture(at fileURL: URL) throws -> ChromeDocumentFingerprint {
        let data: Data
        let attributes: [FileAttributeKey: Any]
        do {
            data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
            attributes = try FileManager().attributesOfItem(
                atPath: fileURL.path(percentEncoded: false)
            )
        } catch {
            throw mappedReadError(error, fileURL: fileURL)
        }

        guard let fileSize = (attributes[.size] as? NSNumber)?.uint64Value,
              let modificationDate = attributes[.modificationDate] as? Date,
              let fileSystemNumber = (attributes[.systemNumber] as? NSNumber)?.uint64Value,
              let fileNumber = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value,
              fileSize == data.count else {
            throw ChromePersistenceError.invalidFingerprint
        }

        return ChromeDocumentFingerprint(
            contentDigest: digest(of: data),
            fileSize: fileSize,
            modificationDate: modificationDate,
            fileSystemNumber: fileSystemNumber,
            fileNumber: fileNumber
        )
    }

    static func digest(of data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }

    private static func mappedReadError(
        _ error: any Error,
        fileURL: URL
    ) -> ChromePersistenceError {
        let cocoaError = error as? CocoaError
        if cocoaError?.code == .fileNoSuchFile {
            return .fileMissing
        }
        if cocoaError?.code == .fileReadNoPermission {
            return .accessDenied
        }
        if !FileManager().fileExists(atPath: fileURL.path(percentEncoded: false)) {
            return .fileMissing
        }
        return .invalidFingerprint
    }
}
